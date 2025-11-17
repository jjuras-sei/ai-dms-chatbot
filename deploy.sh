#!/bin/bash

# Deployment script for AI Chatbot application
set -e

# Parse command line arguments
SKIP_BACKEND=false
SKIP_FRONTEND=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-backend     Skip backend deployment (Docker build and ECS update)"
    echo "  --skip-frontend    Skip frontend deployment (Next.js build and S3 upload)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Note: Infrastructure (Terraform) is always deployed regardless of flags."
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-backend)
            SKIP_BACKEND=true
            shift
            ;;
        --skip-frontend)
            SKIP_FRONTEND=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo "=========================================="
echo "AI Chatbot Deployment Script"
echo "=========================================="
echo ""
echo "Deployment Configuration:"
echo "  - Infrastructure: ALWAYS"
echo "  - Backend: $([ "$SKIP_BACKEND" = true ] && echo "SKIP" || echo "DEPLOY")"
echo "  - Frontend: $([ "$SKIP_FRONTEND" = true ] && echo "SKIP" || echo "DEPLOY")"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo ""

# Copy example configuration files if real versions don't exist
echo "Checking configuration files..."
if [ ! -f "system_prompt.txt" ]; then
    echo "  - Copying system_prompt.txt.example to system_prompt.txt"
    cp system_prompt.txt.example system_prompt.txt
fi

if [ ! -f "schema.json" ]; then
    echo "  - Copying schema.json.example to schema.json"
    cp schema.json.example schema.json
fi
echo ""

# Step 1: Initialize and apply Terraform (ALWAYS RUNS)
echo "Step 1: Deploying AWS infrastructure with Terraform..."
cd terraform

if [ ! -f "terraform.tfvars" ]; then
    echo "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "Please edit terraform/terraform.tfvars with your desired values and run this script again."
    exit 1
fi

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get outputs
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(terraform output -raw ecs_service_name)

cd ..

echo ""
echo "Infrastructure deployed successfully!"
echo "ECR Repository: $ECR_REPO_URL"
echo "API Gateway URL: $API_GATEWAY_URL"
echo ""

# Step 2: Build and push backend Docker image (CONDITIONAL)
if [ "$SKIP_BACKEND" = true ]; then
    echo "Step 2: Skipping backend deployment (--skip-backend flag set)"
    echo ""
else
    echo "Step 2: Building and pushing backend Docker image..."
    cd backend

    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

    # Build Docker image
    docker build -t ai-dms-chatbot-backend:latest .

    # Tag and push to ECR
    docker tag ai-dms-chatbot-backend:latest $ECR_REPO_URL:latest
    docker push $ECR_REPO_URL:latest

    cd ..

    echo ""
    echo "Backend Docker image pushed successfully!"
    echo ""

    # Step 3: Update ECS service to use new image
    echo "Step 3: Updating ECS service..."
    aws ecs update-service \
        --no-cli-pager \
        --cluster $ECS_CLUSTER \
        --service $ECS_SERVICE \
        --force-new-deployment \
        --region $AWS_REGION

    echo ""
    echo "ECS service update initiated. Waiting for deployment..."
    aws ecs wait services-stable \
        --cluster $ECS_CLUSTER \
        --services $ECS_SERVICE \
        --region $AWS_REGION

    echo "ECS service updated successfully!"
    echo ""
fi

# Step 4: Build and deploy frontend (CONDITIONAL)
if [ "$SKIP_FRONTEND" = true ]; then
    echo "Step 4: Skipping frontend deployment (--skip-frontend flag set)"
    echo ""
else
    echo "Step 4: Building and deploying frontend..."
    cd frontend

    # Create .env.local with API Gateway URL
    echo "NEXT_PUBLIC_API_URL=$API_GATEWAY_URL" > .env.local

    # Install dependencies and build
    npm install
    npm run build

    # Sync to S3
    aws s3 sync out/ s3://$S3_BUCKET/ --delete

    cd ..

    echo ""
    echo "Frontend uploaded to S3 successfully!"
    echo ""
    
    # Invalidate CloudFront cache
    echo "Invalidating CloudFront cache..."
    cd terraform
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id)
    cd ..
    
    aws cloudfront create-invalidation \
        --no-cli-pager \
        --distribution-id $CLOUDFRONT_ID \
        --paths "/*" \
        --region $AWS_REGION
    
    echo "CloudFront cache invalidation initiated!"
    echo ""
fi

# Get CloudFront distribution URL
cd terraform
CLOUDFRONT_URL=$(terraform output -raw cloudfront_distribution_url)
cd ..

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Deployed Components:"
echo "  - Infrastructure: ✓"
echo "  - Backend: $([ "$SKIP_BACKEND" = true ] && echo "SKIPPED" || echo "✓")"
echo "  - Frontend: $([ "$SKIP_FRONTEND" = true ] && echo "SKIPPED" || echo "✓")"
echo ""
echo "Access URLs:"
echo "  - Frontend: $CLOUDFRONT_URL"
echo "  - API Gateway: $API_GATEWAY_URL"
echo ""
echo "=========================================="
