#!/bin/bash
# Script to set up the infrastructure using Terraform
# Run this script to provision AWS resources

set -e

# Configuration
TERRAFORM_DIR="terraform"
PROJECT_NAME="my-react-app"
ENVIRONMENT="dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Generate SSH key pair if it doesn't exist
generate_ssh_key() {
    local key_name="${PROJECT_NAME}-key"
    local key_path="$HOME/.ssh/${key_name}"
    
    if [ ! -f "${key_path}" ]; then
        print_status "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "${key_path}" -N "" -C "${PROJECT_NAME}@$(hostname)"
        print_status "SSH key pair generated: ${key_path}"
    else
        print_status "SSH key pair already exists: ${key_path}"
    fi
    
    # Export public key for Terraform
    export TF_VAR_public_key=$(cat "${key_path}.pub")
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    
    terraform init
    
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please edit terraform.tfvars with your specific values before proceeding."
        read -p "Press Enter to continue after editing terraform.tfvars..."
    fi
    
    cd ..
}

# Plan Terraform deployment
plan_terraform() {
    print_status "Planning Terraform deployment..."
    cd "$TERRAFORM_DIR"
    
    terraform plan \
        -var="project_name=${PROJECT_NAME}" \
        -var="environment=${ENVIRONMENT}" \
        -out=tfplan
    
    cd ..
}

# Apply Terraform deployment
apply_terraform() {
    print_status "Applying Terraform deployment..."
    cd "$TERRAFORM_DIR"
    
    terraform apply tfplan
    
    # Save outputs to file
    terraform output -json > ../terraform-outputs.json
    
    cd ..
    
    print_status "Infrastructure deployment completed!"
    print_status "Outputs saved to terraform-outputs.json"
}

# Display connection information
show_connection_info() {
    if [ -f "terraform-outputs.json" ]; then
        local public_ip=$(jq -r '.instance_public_ip.value' terraform-outputs.json)
        local key_name="${PROJECT_NAME}-key"
        local key_path="$HOME/.ssh/${key_name}"
        
        print_status "Connection Information:"
        echo "  Public IP: $public_ip"
        echo "  SSH Command: ssh -i $key_path ubuntu@$public_ip"
        echo "  Application URL: http://$public_ip:3000"
        echo ""
        print_status "GitHub Secrets to configure:"
        echo "  AWS_ACCESS_KEY_ID: Your AWS access key"
        echo "  AWS_SECRET_ACCESS_KEY: Your AWS secret key"
        echo "  EC2_SSH_PRIVATE_KEY: $(cat $key_path)"
        echo "  EC2_PUBLIC_KEY: $(cat $key_path.pub)"
        echo "  PRODUCTION_HOST: $public_ip"
        echo "  STAGING_HOST: $public_ip (or separate staging server)"
        echo "  EC2_USER: ubuntu"
    fi
}

# Main execution
main() {
    print_status "Starting infrastructure setup for $PROJECT_NAME..."
    
    check_prerequisites
    generate_ssh_key
    init_terraform
    plan_terraform
    
    # Confirm before applying
    echo ""
    print_warning "This will create AWS resources that may incur charges."
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_terraform
        show_connection_info
        print_status "Setup completed successfully!"
    else
        print_status "Deployment cancelled."
        exit 0
    fi
}

# Run main function
main "$@"
