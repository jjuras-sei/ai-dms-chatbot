#!/bin/bash

# Deployment script for AI Chatbot application
set -e

# Parse command line arguments
SKIP_BACKEND=false
SKIP_FRONTEND=false
CLEAR_DATA=false
OVERWRITE_SYSTEMPROMPT=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-backend              Skip backend deployment (Docker build and ECS update)"
    echo "  --skip-frontend             Skip frontend deployment (Next.js build and S3 upload)"
    echo "  --clear-data                Clear S3 data buckets and DynamoDB table (only if backend is deployed)"
    echo "  --overwrite-systemprompt    Upload and overwrite system prompt in S3 bucket"
    echo "  -h, --help                  Show this help message"
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
        --clear-data)
            CLEAR_DATA=true
            shift
            ;;
        --overwrite-systemprompt)
            OVERWRITE_SYSTEMPROMPT=true
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
echo "  - Clear Data: $([ "$CLEAR_DATA" = true ] && echo "YES" || echo "NO")"
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

# Step 1.5: Upload system prompt to S3 if requested (CONDITIONAL)
if [ "$OVERWRITE_SYSTEMPROMPT" = true ]; then
    echo "Step 1.5: Uploading system prompt to S3..."
    
    # Get system prompt bucket name from terraform
    cd terraform
    SYSTEM_PROMPT_BUCKET=$(terraform output -raw system_prompt_bucket_name)
    cd ..
    
    if [ ! -f "system_prompt.txt" ]; then
        echo "  - Error: system_prompt.txt file not found!"
        exit 1
    fi
    
    echo "  - Uploading system_prompt.txt to s3://$SYSTEM_PROMPT_BUCKET/system_prompt.txt"
    aws s3 cp system_prompt.txt "s3://$SYSTEM_PROMPT_BUCKET/system_prompt.txt" --region "$AWS_REGION"
    
    echo "    ✓ System prompt uploaded successfully!"
    echo ""
fi

# Step 2: Clear data if requested (CONDITIONAL - only when backend is deployed)
if [ "$SKIP_BACKEND" = false ] && [ "$CLEAR_DATA" = true ]; then
    echo "Step 2: Clearing data S3 buckets and DynamoDB table..."
    
    # Get data bucket names and DynamoDB table name from terraform
    cd terraform
    DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "")
    S3_DATA_BUCKETS=$(terraform output -json s3_data_bucket_names 2>/dev/null || echo "[]")
    cd ..
    
    # Clear DynamoDB table if configured
    if [ -n "$DYNAMODB_TABLE" ] && [ "$DYNAMODB_TABLE" != "" ]; then
        echo "  - Clearing DynamoDB table: $DYNAMODB_TABLE"
        
        # Scan and delete all items from the table
        aws dynamodb scan \
            --table-name "$DYNAMODB_TABLE" \
            --attributes-to-get "id" \
            --region "$AWS_REGION" \
            --output json | \
        jq -r '.Items[] | @json' | \
        while read -r item; do
            key=$(echo "$item" | jq '{id: .id}')
            aws dynamodb delete-item \
                --table-name "$DYNAMODB_TABLE" \
                --key "$key" \
                --region "$AWS_REGION" \
                --no-cli-pager
        done
        
        echo "    ✓ DynamoDB table cleared"
    else
        echo "  - No DynamoDB table configured, skipping"
    fi
    
    # Clear S3 data buckets if configured
    if [ "$S3_DATA_BUCKETS" != "[]" ] && [ "$S3_DATA_BUCKETS" != "null" ]; then
        echo "$S3_DATA_BUCKETS" | jq -r '.[]' | while read -r bucket; do
            if [ -n "$bucket" ]; then
                echo "  - Clearing S3 bucket: $bucket"
                aws s3 rm "s3://$bucket/" --recursive --region "$AWS_REGION"
                echo "    ✓ S3 bucket cleared"
            fi
        done
    else
        echo "  - No S3 data buckets configured, skipping"
    fi
    
    echo ""
    echo "Data cleared successfully!"
    echo ""
fi

# Step 3: Build and push backend Docker image (CONDITIONAL)
if [ "$SKIP_BACKEND" = true ]; then
    echo "Step 3: Skipping backend deployment (--skip-backend flag set)"
    echo ""
else
    echo "Step 3: Building and pushing backend Docker image..."
    
    # Copy configuration files into backend directory for Docker build
    echo "  - Copying configuration files to backend/"
    cp system_prompt.txt backend/
    cp schema.json backend/
    
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

    # Step 4: Update ECS service to use new image
    echo "Step 4: Updating ECS service..."
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

# Step 5: Build and deploy frontend (CONDITIONAL)
if [ "$SKIP_FRONTEND" = true ]; then
    echo "Step 5: Skipping frontend deployment (--skip-frontend flag set)"
    echo ""
else
    echo "Step 5: Building and deploying frontend..."
    cd frontend

    # If .env.prod file exists, use the values from that as .env.local instead of building new .env.local
    if [ -f ".env.prod" ]; then
        cp .env.prod .env.local
        echo "  - .env.prod file exists. Copying it to .env.local instead of building new .env.local"
    else
        # Update or create .env.local with API Gateway URL
        if [ -f ".env.local" ]; then
            echo "  - Updating existing .env.local file"
            # Check if NEXT_PUBLIC_API_URL exists in the file
            if grep -q "^NEXT_PUBLIC_API_URL=" .env.local; then
                # Update existing API URL line
                sed -i.bak "s|^NEXT_PUBLIC_API_URL=.*|NEXT_PUBLIC_API_URL=$API_GATEWAY_URL|" .env.local
                rm -f .env.local.bak
            else
                # Add API URL to existing file
                echo "NEXT_PUBLIC_API_URL=$API_GATEWAY_URL" >> .env.local
            fi
        else
            echo "  - Creating new .env.local file"
            echo "NEXT_PUBLIC_API_URL=$API_GATEWAY_URL" > .env.local
        fi
    fi

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
