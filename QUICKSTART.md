# Quick Start Guide

This guide will help you get the AI Chatbot application up and running quickly.

## Prerequisites Checklist

- [ ] AWS Account created
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Docker installed and running
- [ ] Terraform installed (>= 1.0)
- [ ] Node.js installed (>= 18)
- [ ] Python installed (>= 3.11)

## 5-Minute Setup

### 1. Configure AWS Bedrock Access

```bash
# Go to AWS Console
# Navigate to: Bedrock → Model access
# Click "Manage model access"
# Enable: Claude 3 Sonnet (or your preferred model)
# Submit and wait for approval
```

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed
# Key variables: project_name (default: ai-dms-chatbot), resource_suffix (default: dev)
cd ..
```

### 3. Deploy Everything

```bash
./deploy.sh
```

This single command will:
- ✅ Create all AWS infrastructure
- ✅ Build and deploy the backend
- ✅ Build and deploy the frontend
- ✅ Display the application URL

### 4. Access Your Chatbot

Wait for the deployment to complete (5-10 minutes), then:

```bash
cd terraform
terraform output cloudfront_distribution_url
```

Open the URL in your browser and start chatting!

## Testing Locally (Optional)

### Backend

```bash
cd backend
pip install -r requirements.txt
export AWS_REGION=us-east-1
export BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
python main.py
```

Visit: http://localhost:8000/health

### Frontend

```bash
cd frontend
npm install
echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > .env.local
npm run dev
```

Visit: http://localhost:3000

## Common Issues

### "AWS CLI not configured"
```bash
aws configure
# Enter your AWS credentials
```

### "Bedrock Access Denied"
- Enable model access in AWS Console → Bedrock → Model access
- Ensure you're in a supported region (us-east-1, us-west-2, etc.)

### "Docker not running"
```bash
# Start Docker Desktop or Docker daemon
docker ps
```

### "Terraform apply failed"
- Check if you hit AWS service limits
- Verify IAM permissions
- Run `terraform destroy` and try again

## What Gets Created?

The deployment creates:

- **Frontend**: Next.js app on S3 + CloudFront
- **Backend**: FastAPI on ECS Fargate
- **Networking**: VPC, subnets, NAT gateways, ALB
- **API**: API Gateway for backend access
- **Storage**: ECR for Docker images
- **Monitoring**: CloudWatch logs

## Cost Estimate

~$50-70/month + Bedrock usage (pay per token)

## Next Steps

1. Test the chatbot with various questions
2. Start a new conversation using "New Question" button
3. Monitor costs in AWS Cost Explorer
4. Customize the model in `terraform.tfvars`
5. Read the full README.md for advanced features

## Cleanup

When done testing, use the automated destroy script:

```bash
./destroy.sh
```

This will safely:
- Empty the S3 bucket
- Remove all infrastructure
- Provide confirmation before deletion

**Alternative manual method:**
```bash
cd terraform
terraform destroy
```

## Support

- Full documentation: See README.md
- Issues: Check troubleshooting section in README
- Logs: `aws logs tail /ecs/ai-chatbot-backend --follow`

---

Happy Chatting! 🤖
