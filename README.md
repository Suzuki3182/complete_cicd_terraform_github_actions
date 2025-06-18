# CI/CD Pipeline with GitHub Actions and AWS EC2

This project implements a complete CI/CD pipeline using GitHub Actions for automation and AWS EC2 for hosting, with infrastructure managed by Terraform.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitHub Actions │    │   AWS EC2       │
│                 │───▶│                  │───▶│                 │
│   Push Code     │    │   Build & Deploy │    │   Host App      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Terraform      │
                       │   Infrastructure │
                       └──────────────────┘
```

## Features

- **Infrastructure as Code**: Complete AWS infrastructure defined in Terraform
- **Automated CI/CD**: GitHub Actions workflow for build, test, and deployment
- **Security**: Proper IAM roles, security groups, and encrypted storage
- **Monitoring**: CloudWatch integration and application health checks
- **Scalability**: Load balancer ready configuration with auto-scaling capabilities
- **Rollback**: Automated backup and rollback mechanisms

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **GitHub Account** with a repository for your project
3. **Local Development Environment** with:
   - Terraform >= 1.0
   - AWS CLI v2
   - Node.js >= 18
   - SSH client

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd <your-repo-name>
```

### 2. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and default region
```

### 3. Deploy Infrastructure

```bash
# Make the setup script executable
chmod +x scripts/setup-infrastructure.sh

# Run the setup script
./scripts/setup-infrastructure.sh
```

The script will:
- Generate SSH key pairs
- Initialize Terraform
- Create a deployment plan
- Deploy AWS infrastructure
- Provide connection details

### 4. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key for deployment | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for deployment | `wJalrXUt...` |
| `EC2_SSH_PRIVATE_KEY` | Private SSH key for EC2 access | `-----BEGIN RSA PRIVATE KEY-----...` |
| `EC2_PUBLIC_KEY` | Public SSH key for EC2 access | `ssh-rsa AAAAB3...` |
| `PRODUCTION_HOST` | Production server IP address | `54.123.45.67` |
| `STAGING_HOST` | Staging server IP address | `54.123.45.68` |
| `EC2_USER` | EC2 instance username | `ubuntu` |

### 5. Deploy Your Application

Push your code to trigger the CI/CD pipeline:

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

## Infrastructure Components

### AWS Resources Created

- **VPC**: Isolated network environment
- **EC2 Instance**: Application server with Ubuntu 22.04
- **Security Groups**: Firewall rules for HTTP/HTTPS/SSH access
- **Elastic IP**: Static IP address for the instance
- **IAM Roles**: Permissions for EC2 and deployment
- **S3 Bucket**: Storage for deployment artifacts
- **CloudWatch**: Monitoring and logging

### Network Architecture

```
Internet Gateway
       │
   ┌───▼────┐
   │   VPC  │ (10.0.0.0/16)
   │        │
   └───┬────┘
       │
┌──────▼──────┐
│ Public      │ (10.0.1.0/24)
│ Subnet      │
│             │
│ ┌─────────┐ │
│ │   EC2   │ │
│ │Instance │ │
│ └─────────┘ │
└─────────────┘
```

## CI/CD Pipeline

### Workflow Stages

1. **Test and Build**
   - Checkout code
   - Install dependencies
   - Run linting and tests
   - Build application
   - Upload artifacts

2. **Deploy to Staging** (develop branch)
   - Download build artifacts
   - Deploy to staging server
   - Run health checks

3. **Deploy to Production** (main branch)
   - Create deployment backup
   - Deploy to production server
   - Run comprehensive health checks
   - Send notifications

### Branch Strategy

- `main`: Production deployments
- `develop`: Staging deployments
- `feature/*`: Pull request validation

## Application Management

### PM2 Process Manager

The application uses PM2 for process management:

```bash
# View application status
pm2 status

# View logs
pm2 logs my-react-app

# Restart application
pm2 restart my-react-app

# Monitor resources
pm2 monit
```

### Nginx Reverse Proxy

Nginx serves as a reverse proxy:

- **Port 80**: HTTP traffic forwarded to application
- **Port 443**: HTTPS (configure SSL certificates as needed)
- **Health Check**: `/health` endpoint for monitoring

### Log Management

Logs are stored in `/var/log/my-react-app/`:
- `combined.log`: All application logs
- `out.log`: Standard output
- `error.log`: Error logs

Log rotation is configured automatically.

## Monitoring and Maintenance

### Health Checks

The pipeline includes multiple health check layers:
1. Application health endpoint (`/health`)
2. PM2 process monitoring
3. Nginx status checks
4. CloudWatch metrics

### Backup Strategy

- **Automatic Backups**: Created before each production deployment
- **Retention**: 30 days of deployment backups
- **Location**: `/opt/my-react-app/backups/`

### Scaling Considerations

To scale the application:

1. **Vertical Scaling**: Increase EC2 instance size
2. **Horizontal Scaling**: Add Application Load Balancer and Auto Scaling Group
3. **Database**: Add RDS for persistent data
4. **CDN**: Add CloudFront for static assets

## Security Best Practices

### Implemented Security Measures

- **Encrypted EBS volumes**
- **IAM roles with least privilege**
- **Security groups with minimal required access**
- **SSH key-based authentication**
- **Regular security updates via user data script**

### Additional Security Recommendations

1. **SSL/TLS**: Configure HTTPS with Let's Encrypt
2. **WAF**: Add AWS WAF for application protection
3. **VPN**: Use VPN for SSH access in production
4. **Secrets Management**: Use AWS Secrets Manager for sensitive data

## Troubleshooting

### Common Issues

1. **Deployment Fails**
   ```bash
   # Check GitHub Actions logs
   # SSH to server and check application logs
   ssh -i ~/.ssh/my-react-app-key ubuntu@<server-ip>
   sudo -u appuser pm2 logs
   ```

2. **Application Not Accessible**
   ```bash
   # Check security group rules
   # Verify nginx configuration
   sudo nginx -t
   sudo systemctl status nginx
   ```

3. **High Memory Usage**
   ```bash
   # Monitor with PM2
   pm2 monit
   # Check system resources
   htop
   ```

### Rollback Procedure

If a deployment fails:

1. **Automatic Rollback**: Pipeline includes health checks
2. **Manual Rollback**:
   ```bash
   # SSH to server
   cd /opt/my-react-app/backups
   # Restore from latest backup
   tar -xzf backup-YYYYMMDD-HHMMSS.tar.gz -C ..
   pm2 restart my-react-app
   ```

## Cost Optimization

### Current Costs (Estimated)

- **EC2 t3.micro**: ~$8.50/month
- **EBS 20GB**: ~$2.00/month
- **Elastic IP**: ~$3.65/month (when not attached)
- **Data Transfer**: Variable based on usage

### Cost Reduction Tips

1. **Reserved Instances**: Save up to 75% for predictable workloads
2. **Spot Instances**: Use for development/testing environments
3. **Auto Scaling**: Scale down during low usage periods
4. **CloudWatch**: Monitor and optimize resource usage

## Cleanup

To destroy all AWS resources:

```bash
chmod +x scripts/destroy-infrastructure.sh
./scripts/destroy-infrastructure.sh
```

**Warning**: This will permanently delete all resources and data.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review GitHub Actions logs
3. Check AWS CloudWatch logs
4. Create an issue in the repository

## License

This project is licensed under the MIT License - see the LICENSE file for details.
# complete_cicd_terraform_github_actions
