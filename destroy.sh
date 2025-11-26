#!/bin/bash

# Destroy script for AI Chatbot application
set -e

echo "=========================================="
echo "AI Chatbot Infrastructure Destruction"
echo "=========================================="
echo ""
echo "WARNING: This will DELETE all resources including:"
echo "  - S3 bucket and all files"
echo "  - ECS cluster and services"
echo "  - VPC and networking components"
echo "  - ECR repository and Docker images"
echo "  - CloudFront distribution"
echo "  - All other AWS resources"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

echo ""
echo "Starting infrastructure destruction..."
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

AWS_REGION=${AWS_REGION:-us-east-1}

# Change to terraform directory
cd terraform

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "Warning: No terraform.tfstate file found."
    echo "Infrastructure may not have been deployed or state file is missing."
    read -p "Continue with destroy anyway? (yes/no): " continue_destroy
    if [ "$continue_destroy" != "yes" ]; then
        echo "Destruction cancelled."
        exit 0
    fi
fi

# Initialize Terraform (in case it hasn't been initialized)
echo "Initializing Terraform..."
terraform init

# Get S3 bucket name from Terraform output
echo ""
echo "Step 1: Emptying S3 bucket..."
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")

if [ -n "$S3_BUCKET" ]; then
    echo "Found S3 bucket: $S3_BUCKET"
    
    # Check if bucket exists
    if aws s3 ls "s3://$S3_BUCKET" --region $AWS_REGION &> /dev/null; then
        echo "Emptying bucket contents..."
        
        # Delete all objects in the bucket
        aws s3 rm "s3://$S3_BUCKET" --recursive --region $AWS_REGION
        
        # Delete all versions if versioning is enabled
        aws s3api delete-objects --bucket "$S3_BUCKET" --region $AWS_REGION \
            --delete "$(aws s3api list-object-versions --bucket "$S3_BUCKET" --region $AWS_REGION \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --max-items 1000)" \
            2>/dev/null || true
        
        # Delete all delete markers
        aws s3api delete-objects --bucket "$S3_BUCKET" --region $AWS_REGION \
            --delete "$(aws s3api list-object-versions --bucket "$S3_BUCKET" --region $AWS_REGION \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --max-items 1000)" \
            2>/dev/null || true
        
        echo "S3 bucket emptied successfully."
    else
        echo "S3 bucket does not exist or is already deleted."
    fi
else
    echo "No S3 bucket found in Terraform outputs."
fi

echo ""
echo "Step 2: Emptying ECR repository..."
ECR_REPO_NAME=$(terraform output -raw ecr_repository_url 2>/dev/null | cut -d'/' -f2 || echo "")

if [ -n "$ECR_REPO_NAME" ]; then
    echo "Found ECR repository: $ECR_REPO_NAME"
    
    # Check if repository exists
    if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region $AWS_REGION &> /dev/null; then
        echo "Deleting all images in ECR repository..."
        
        # Get all image digests and delete them
        IMAGE_DIGESTS=$(aws ecr list-images --repository-name "$ECR_REPO_NAME" --region $AWS_REGION \
            --query 'imageIds[*].imageDigest' --output text 2>/dev/null || echo "")
        
        if [ -n "$IMAGE_DIGESTS" ]; then
            for digest in $IMAGE_DIGESTS; do
                aws ecr batch-delete-image --repository-name "$ECR_REPO_NAME" --region $AWS_REGION \
                    --image-ids imageDigest=$digest &> /dev/null || true
            done
            echo "ECR repository emptied successfully."
        else
            echo "ECR repository is already empty."
        fi
    else
        echo "ECR repository does not exist or is already deleted."
    fi
else
    echo "No ECR repository found in Terraform outputs."
fi

echo ""
echo "Step 3: Destroying infrastructure with Terraform..."
echo ""

# Run terraform destroy
terraform destroy -auto-approve

cd ..

echo ""
echo "=========================================="
echo "Infrastructure Destruction Complete!"
echo "=========================================="
echo ""
echo "All AWS resources have been removed."
echo "The following local files remain:"
echo "  - Project source code"
echo "  - terraform.tfstate.backup (if it exists)"
echo ""
echo "To completely remove the project:"
echo "  rm -rf .terraform terraform.tfstate* frontend/node_modules frontend/.next"
echo "=========================================="
