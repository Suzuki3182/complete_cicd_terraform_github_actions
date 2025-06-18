// PM2 ecosystem configuration for the React application
// This file defines how PM2 should manage the application process

module.exports = {
  apps: [{
    name: 'my-react-app',
    script: 'serve',
    args: '-s dist -l 3000',
    instances: 1,
    exec_mode: 'fork',
    
    // Environment variables
    env: {
      NODE_ENV: 'development',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    
    // Logging configuration
    log_file: '/var/log/my-react-app/combined.log',
    out_file: '/var/log/my-react-app/out.log',
    error_file: '/var/log/my-react-app/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    
    // Process management
    max_memory_restart: '500M',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s',
    
    // Monitoring
    watch: false,
    ignore_watch: ['node_modules', 'logs'],
    
    // Advanced options
    kill_timeout: 5000,
    listen_timeout: 8000,
    
    // Health check (if your app supports it)
    health_check_grace_period: 3000,
    health_check_fatal_exceptions: true
  }],

  // Deployment configuration (optional)
  deploy: {
    production: {
      user: 'appuser',
      host: ['your-production-server.com'],
      ref: 'origin/main',
      repo: 'git@github.com:yourusername/your-repo.git',
      path: '/opt/my-react-app',
      'post-deploy': 'npm install && npm run build && pm2 reload ecosystem.config.js --env production',
      'pre-setup': 'apt update && apt install git -y'
    },
    staging: {
      user: 'appuser',
      host: ['your-staging-server.com'],
      ref: 'origin/develop',
      repo: 'git@github.com:yourusername/your-repo.git',
      path: '/opt/my-react-app',
      'post-deploy': 'npm install && npm run build && pm2 reload ecosystem.config.js --env staging',
      'pre-setup': 'apt update && apt install git -y'
    }
  }
};
