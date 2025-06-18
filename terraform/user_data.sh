#!/bin/bash
# User data script for EC2 instance initialization
# This script runs when the instance first boots up

set -e

# Update system packages
apt-get update -y
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    htop \
    nginx \
    supervisor

# Install Node.js (adjust version as needed)
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install PM2 for process management
npm install -g pm2

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create application user
useradd -m -s /bin/bash appuser
usermod -aG sudo appuser

# Create application directory
mkdir -p /opt/${project_name}
chown appuser:appuser /opt/${project_name}

# Create logs directory
mkdir -p /var/log/${project_name}
chown appuser:appuser /var/log/${project_name}

# Configure nginx (basic configuration)
cat > /etc/nginx/sites-available/${project_name} << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:${app_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/${project_name} /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Start and enable services
systemctl enable nginx
systemctl start nginx
systemctl enable supervisor
systemctl start supervisor

# Configure PM2 startup
sudo -u appuser pm2 startup systemd -u appuser --hp /home/appuser
systemctl enable pm2-appuser

# Create deployment script
cat > /opt/${project_name}/deploy.sh << 'EOF'
#!/bin/bash
# Deployment script for the application

set -e

PROJECT_NAME="${project_name}"
APP_DIR="/opt/$PROJECT_NAME"
LOG_DIR="/var/log/$PROJECT_NAME"
APP_PORT="${app_port}"

echo "Starting deployment at $(date)"

# Change to application directory
cd $APP_DIR

# Install dependencies
echo "Installing dependencies..."
npm ci --production

# Run any build steps (adjust as needed)
if [ -f "package.json" ] && grep -q "build" package.json; then
    echo "Building application..."
    npm run build
fi

# Stop existing application
echo "Stopping existing application..."
pm2 stop $PROJECT_NAME || true

# Start application with PM2
echo "Starting application..."
pm2 start ecosystem.config.js --env production

# Save PM2 configuration
pm2 save

echo "Deployment completed at $(date)"
EOF

chmod +x /opt/${project_name}/deploy.sh
chown appuser:appuser /opt/${project_name}/deploy.sh

# Create PM2 ecosystem file
cat > /opt/${project_name}/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: '${project_name}',
    script: './src/main.tsx', // Adjust based on your app entry point
    instances: 1,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'development',
      PORT: ${app_port}
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: ${app_port}
    },
    log_file: '/var/log/${project_name}/combined.log',
    out_file: '/var/log/${project_name}/out.log',
    error_file: '/var/log/${project_name}/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
EOF

chown appuser:appuser /opt/${project_name}/ecosystem.config.js

# Create systemd service for the application (alternative to PM2)
cat > /etc/systemd/system/${project_name}.service << EOF
[Unit]
Description=${project_name} Application
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/${project_name}
ExecStart=/usr/bin/node src/main.tsx
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=${app_port}

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${project_name}

[Install]
WantedBy=multi-user.target
EOF

# Set up log rotation
cat > /etc/logrotate.d/${project_name} << EOF
/var/log/${project_name}/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 appuser appuser
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

# Configure firewall (UFW)
ufw --force enable
ufw allow ssh
ufw allow http
ufw allow https
ufw allow ${app_port}

# Install CloudWatch agent (optional)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/${project_name}/*.log",
                        "log_group_name": "/aws/ec2/${project_name}",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "${project_name}/EC2",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Signal that user data script has completed
/opt/aws/bin/cfn-signal -e $? --stack ${project_name} --resource AutoScalingGroup --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region) || true

echo "User data script completed successfully at $(date)" >> /var/log/user-data.log
