#!/bin/bash
# Script to destroy the infrastructure using Terraform
# WARNING: This will delete all AWS resources created by Terraform

set -e

# Configuration
TERRAFORM_DIR="terraform"
PROJECT_NAME="my-react-app"

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

# Main execution
main() {
    print_warning "This will DESTROY all AWS resources created by Terraform!"
    print_warning "This action cannot be undone!"
    echo ""
    
    # Show what will be destroyed
    cd "$TERRAFORM_DIR"
    
    if [ -f "terraform.tfstate" ]; then
        print_status "Resources that will be destroyed:"
        terraform show -no-color | grep -E "^resource|^data" || true
        echo ""
    else
        print_error "No Terraform state file found. Nothing to destroy."
        exit 1
    fi
    
    # Double confirmation
    read -p "Are you absolutely sure you want to destroy all resources? Type 'yes' to confirm: " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        print_status "Destruction cancelled."
        exit 0
    fi
    
    print_status "Destroying infrastructure..."
    terraform destroy -auto-approve
    
    cd ..
    
    # Clean up local files
    rm -f terraform-outputs.json
    
    print_status "Infrastructure destroyed successfully!"
    print_warning "Don't forget to remove the SSH key from ~/.ssh/ if no longer needed."
}

# Run main function
main "$@"
