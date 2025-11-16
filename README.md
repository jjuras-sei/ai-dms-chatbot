# AI Chatbot Application

A full-stack conversational AI chatbot application powered by AWS Bedrock, featuring a FastAPI backend and Next.js frontend, deployed on AWS infrastructure using Terraform.

## Features

- **Conversational AI**: Powered by AWS Bedrock with support for various models (Claude, Llama, Titan)
- **Conversation History**: Maintains context across messages for natural conversations
- **Modern UI**: Clean, responsive interface built with Next.js and Tailwind CSS
- **New Question Button**: Easily start fresh conversations while maintaining previous context
- **Cloud Infrastructure**: Fully automated AWS deployment using Terraform
- **Scalable Architecture**: ECS Fargate for backend, CloudFront for frontend distribution

## Architecture

### Frontend
- **Framework**: Next.js 14 with TypeScript
- **Styling**: Tailwind CSS
- **Hosting**: AWS S3 + CloudFront
- **Features**: Static site generation (SSG) for optimal performance

### Backend
- **Framework**: FastAPI (Python)
- **AI Integration**: AWS Bedrock
- **Hosting**: AWS ECS Fargate
- **API Gateway**: AWS API Gateway (HTTP API)
- **Container Registry**: AWS ECR

### Infrastructure
- **IaC**: Terraform
- **Networking**: VPC with public/private subnets, NAT Gateway, ALB
- **Security**: Security groups, IAM roles with least privilege
- **Monitoring**: CloudWatch Logs

## Prerequisites

- **AWS Account** with appropriate permissions
- **AWS CLI** configured with credentials (`aws configure`)
- **Docker** installed and running
- **Terraform** >= 1.0
- **Node.js** >= 18
- **Python** >= 3.11
- **Git**

## Project Structure

```
ai-dms-chatbot/
├── backend/
│   ├── main.py              # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   └── Dockerfile          # Docker configuration
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── page.tsx    # Main chat interface
│   │   │   ├── layout.tsx  # Root layout
│   │   │   └── globals.css # Global styles
│   │   └── components/
│   │       └── ChatMessage.tsx  # Message component
│   ├── package.json
│   ├── tsconfig.json
│   ├── tailwind.config.ts
│   └── next.config.js
├── terraform/
│   ├── main.tf             # Main infrastructure
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   └── terraform.tfvars.example
├── deploy.sh               # Automated deployment script
└── README.md
```

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd ai-dms-chatbot
```

### 2. Configure AWS Credentials

```bash
aws configure
```

Enter your AWS Access Key ID, Secret Access Key, and preferred region.

### 3. Enable AWS Bedrock Models

Before deploying, ensure you have access to AWS Bedrock models:

1. Go to AWS Console → Bedrock → Model access
2. Request access to the desired models (e.g., Claude 3 Sonnet)
3. Wait for approval (usually instant for most models)

### 4. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to customize:

```hcl
aws_region         = "us-east-1"
project_name       = "ai-dms-chatbot"
resource_suffix    = "dev"
bedrock_model_id   = "anthropic.claude-3-sonnet-20240229-v1:0"
ecs_task_cpu       = "512"
ecs_task_memory    = "1024"
ecs_desired_count  = 1
```

### 5. Deploy the Application

#### Option A: Automated Deployment (Recommended)

```bash
chmod +x deploy.sh
./deploy.sh
```

This script will:
1. Deploy AWS infrastructure with Terraform
2. Build and push the backend Docker image to ECR
3. Update ECS service with the new image
4. Build and deploy the frontend to S3/CloudFront

#### Option B: Manual Deployment

**Step 1: Deploy Infrastructure**
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**Step 2: Build and Push Backend**
```bash
cd ../backend

# Get ECR repository URL from Terraform output
ECR_REPO_URL=$(cd ../terraform && terraform output -raw ecr_repository_url)
AWS_REGION=$(cd ../terraform && terraform output -raw aws_region)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build and push
docker build -t ai-chatbot-backend:latest .
docker tag ai-chatbot-backend:latest $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:latest
```

**Step 3: Update ECS Service**
```bash
ECS_CLUSTER=$(cd ../terraform && terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(cd ../terraform && terraform output -raw ecs_service_name)

aws ecs update-service \
    --cluster $ECS_CLUSTER \
    --service $ECS_SERVICE \
    --force-new-deployment \
    --region $AWS_REGION
```

**Step 4: Build and Deploy Frontend**
```bash
cd ../frontend

# Get API Gateway URL
API_GATEWAY_URL=$(cd ../terraform && terraform output -raw api_gateway_url)
echo "NEXT_PUBLIC_API_URL=$API_GATEWAY_URL" > .env.local

# Build and deploy
npm install
npm run build

# Upload to S3
S3_BUCKET=$(cd ../terraform && terraform output -raw s3_bucket_name)
aws s3 sync out/ s3://$S3_BUCKET/ --delete
```

### 6. Access the Application

After deployment completes:

```bash
cd terraform
terraform output cloudfront_distribution_url
```

Open the CloudFront URL in your browser. Note: CloudFront distribution may take 10-15 minutes to fully propagate.

## Local Development

### Backend

```bash
cd backend
pip install -r requirements.txt

# Set environment variables
export AWS_REGION=us-east-1
export BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0

# Run the server
python main.py
```

Backend will be available at `http://localhost:8000`

### Frontend

```bash
cd frontend
npm install

# Create .env.local
echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > .env.local

# Run development server
npm run dev
```

Frontend will be available at `http://localhost:3000`

## API Endpoints

### Backend API

- `GET /` - Root endpoint
- `GET /health` - Health check
- `POST /chat` - Send a message and get AI response
  ```json
  {
    "conversation_id": "optional-uuid",
    "message": "Hello, how are you?"
  }
  ```
- `GET /conversation/{conversation_id}` - Retrieve conversation history
- `DELETE /conversation/{conversation_id}` - Delete conversation (start new)

## Supported Bedrock Models

The application supports the following AWS Bedrock models:

- `anthropic.claude-3-sonnet-20240229-v1:0` (Default)
- `anthropic.claude-3-haiku-20240307-v1:0`
- `anthropic.claude-v2:1`
- `anthropic.claude-v2`
- `anthropic.claude-instant-v1`
- `meta.llama2-13b-chat-v1`
- `meta.llama2-70b-chat-v1`
- `amazon.titan-text-express-v1`

Change the model by updating the `bedrock_model_id` variable in `terraform.tfvars`.

## Configuration

### Environment Variables

**Backend:**
- `AWS_REGION` - AWS region for Bedrock
- `BEDROCK_MODEL_ID` - Bedrock model identifier

**Frontend:**
- `NEXT_PUBLIC_API_URL` - Backend API URL

### Terraform Variables

See `terraform/variables.tf` for all configurable options:
- AWS region and project name
- Bedrock model selection
- ECS task sizing (CPU/memory)
- Desired task count for scaling

## Monitoring and Logs

### CloudWatch Logs

View backend logs:
```bash
aws logs tail /ecs/ai-chatbot-backend --follow
```

### ECS Service Status

Check ECS service health:
```bash
aws ecs describe-services \
    --cluster ai-chatbot-cluster \
    --services ai-chatbot-backend-service
```

## Troubleshooting

### Backend Not Responding

1. Check ECS task status:
   ```bash
   aws ecs list-tasks --cluster ai-chatbot-cluster
   ```

2. View task logs in CloudWatch

3. Verify security group allows traffic on port 8000

### Frontend Not Loading

1. Check S3 bucket contents
2. Verify CloudFront distribution is deployed
3. Check browser console for CORS errors
4. Ensure API Gateway URL is correctly set in frontend

### Bedrock Access Denied

1. Verify IAM role has Bedrock permissions
2. Confirm model access is enabled in Bedrock console
3. Check the model ID is correct and available in your region

## Cleanup

To safely destroy all AWS resources including clearing S3 buckets:

```bash
./destroy.sh
```

This script will:
1. Empty the S3 bucket (remove all files)
2. Clear ECR repository information
3. Destroy all infrastructure with Terraform

The script includes safety confirmations before deletion.

**Alternative: Manual Cleanup**
```bash
cd terraform
terraform destroy
```

**Warning**: Manual cleanup may fail if S3 bucket contains files. Use the destroy.sh script for a clean removal.

## Cost Estimation

Approximate monthly costs (us-east-1, minimal usage):

- **ECS Fargate**: ~$15-30 (1 task, 0.5 vCPU, 1GB RAM)
- **API Gateway**: ~$3.50 (1M requests)
- **CloudFront**: ~$1-5 (depends on traffic)
- **NAT Gateway**: ~$32 (per NAT Gateway)
- **S3**: ~$0.50 (minimal storage)
- **Bedrock**: Pay per token (varies by model)

**Total**: ~$50-70/month + Bedrock usage

To reduce costs:
- Use a single NAT Gateway (remove HA)
- Use AWS Free Tier where applicable
- Scale down ECS tasks when not in use

## Security Considerations

- Backend runs in private subnets with no direct internet access
- IAM roles follow least privilege principle
- API Gateway provides rate limiting
- CORS configured for frontend domain
- Security groups restrict traffic to necessary ports

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- Check the troubleshooting section
- Review CloudWatch logs
- Open an issue in the repository

## Roadmap

- [ ] Add DynamoDB for persistent conversation storage
- [ ] Implement user authentication (Cognito)
- [ ] Add conversation history UI
- [ ] Support for file uploads
- [ ] Multi-model switching in UI
- [ ] Streaming responses
- [ ] Rate limiting per user
- [ ] Custom domain support

---

Built with ❤️ using AWS, FastAPI, and Next.js
