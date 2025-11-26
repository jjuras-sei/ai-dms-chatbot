# Private Deployment Mode Guide

This document explains how to deploy the AI DMS Chatbot infrastructure in private mode, where the backend is not publicly accessible and uses AWS VPC Link for secure connectivity.

## Overview

Private deployment mode allows you to deploy the application stack entirely within private IP space, with the Application Load Balancer (ALB) hosted in private subnets and accessed through API Gateway via VPC Link.

## Architecture

### Public Mode (Default)
```
Internet → CloudFront (Frontend)
Internet → API Gateway → ALB (Public Subnets) → ECS (Private Subnets)
```

### Private Mode
```
Internet → CloudFront (Frontend)
Internet → API Gateway → VPC Link → ALB (Private Subnets) → ECS (Private Subnets)
```

## Key Differences

| Component | Public Mode | Private Mode |
|-----------|-------------|--------------|
| ALB Type | Internet-facing | Internal |
| ALB Subnets | Public subnets | Private subnets |
| API Gateway Connection | Direct HTTP to public ALB | VPC Link to private ALB |
| ALB Security | Open to internet (0.0.0.0/0) | Restricted to VPC CIDR |
| Public IPs | ALB has public IPs | No public IPs on ALB |

## Configuration

### Enable Private Mode

Add the following to your `terraform.tfvars`:

```hcl
enable_private_deployment = true
```

### Complete Example

```hcl
# terraform.tfvars

# Basic configuration
aws_region      = "us-east-1"
project_name    = "ai-dms-chatbot"
resource_suffix = "prod"

# Enable private deployment
enable_private_deployment = true

# Optionally use existing VPC
existing_vpc_id = "vpc-0123456789abcdef0"
existing_public_subnet_ids = [
  "subnet-pub-1a",
  "subnet-pub-1b"
]
existing_private_subnet_ids = [
  "subnet-priv-1a",
  "subnet-priv-1b"
]

# Other configurations
dynamodb_table_name = "my-dms-table"
s3_bucket_names     = ["my-data-bucket"]
```

## Infrastructure Components

### VPC Link
- Automatically created when `enable_private_deployment = true`
- Establishes secure connection between API Gateway and private ALB
- Deployed in private subnets
- Has its own security group for traffic management

### Internal ALB
- Deployed in private subnets (no public IPs)
- Only accessible within VPC or via VPC Link
- Security group restricts ingress to VPC CIDR block

### Security Groups

**ALB Security Group (Private Mode):**
- Ingress: Ports 80/443 from VPC CIDR only
- Egress: All traffic

**ECS Security Group:**
- Ingress: Port 8000 from ALB security group only
- Egress: All traffic

**VPC Link Security Group:**
- Egress: All traffic (for connecting to ALB)

## Requirements

### Network Requirements
1. **Private Subnets:** Must have NAT Gateway or NAT Instance access for:
   - ECS tasks to pull container images from ECR
   - Backend to access AWS services (Bedrock, DynamoDB, S3)
   - CloudWatch logging

2. **VPC Configuration:**
   - DNS hostnames enabled
   - DNS resolution enabled
   - At least 2 private subnets in different AZs

### Service Endpoints (Optional but Recommended)
For enhanced security and reduced NAT costs, consider creating VPC endpoints for:
- ECR (API and DKR)
- CloudWatch Logs
- DynamoDB
- S3
- Bedrock

## Security Benefits

1. **No Public Exposure:** ALB has no public IP address or internet routing
2. **Reduced Attack Surface:** Backend infrastructure fully isolated in private network
3. **Controlled Access:** API Gateway is the only public entry point
4. **Compliance Ready:** Suitable for organizations with strict security requirements
5. **Network Isolation:** Traffic between API Gateway and ALB stays within AWS backbone

## Cost Considerations

### Additional Costs in Private Mode

1. **VPC Link:** ~$0.01/hour (~$7.50/month)
2. **Data Transfer:** VPC Link data processing charges (~$0.01/GB)

### Potential Savings

- No need for public IPs on ALB (minimal, but ALB doesn't charge for IPs)
- Can share VPC Link across multiple APIs

### Overall Impact
- Typically adds ~$10-15/month to infrastructure costs
- Cost increase is minimal compared to security benefits

## Deployment Steps

1. **Configure Variables:**
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   # Edit terraform.tfvars and set enable_private_deployment = true
   ```

2. **Initialize Terraform:**
   ```bash
   cd terraform
   terraform init
   ```

3. **Review Plan:**
   ```bash
   terraform plan
   ```
   Verify that VPC Link resources will be created

4. **Apply Configuration:**
   ```bash
   terraform apply
   ```

5. **Verify Deployment:**
   - Check VPC Link status in API Gateway console (should be "AVAILABLE")
   - Verify ALB is internal with private IPs only
   - Test API Gateway endpoint

## Monitoring

### VPC Link Health
- Monitor VPC Link status in API Gateway console
- Check CloudWatch metrics for `VpcLinkStatus`
- Set up alarms for VPC Link availability

### ALB Health
- Monitor target group health checks
- Review ECS task connectivity
- Check security group rules if health checks fail

## Troubleshooting

### VPC Link Shows "FAILED" Status
**Causes:**
- Invalid security group configuration
- Subnets not accessible
- ENI creation failed

**Resolution:**
1. Check VPC Link security group allows egress
2. Verify subnets have available IP addresses
3. Ensure subnets are in correct AZs
4. Check VPC DNS settings are enabled

### API Gateway Returns 503 Service Unavailable
**Causes:**
- VPC Link not ready
- ALB not healthy
- Security groups blocking traffic

**Resolution:**
1. Wait for VPC Link to reach "AVAILABLE" status
2. Check ALB target health in EC2 console
3. Verify security group rules allow VPC Link → ALB traffic
4. Review CloudWatch logs for detailed errors

### ECS Tasks Cannot Start
**Causes:**
- No NAT Gateway access
- Cannot pull images from ECR
- Cannot reach AWS services

**Resolution:**
1. Verify private subnets have NAT Gateway routes
2. Check security groups allow outbound traffic
3. Consider adding VPC endpoints for ECR
4. Review ECS task logs for specific errors

### High Latency
**Causes:**
- NAT Gateway bottleneck
- Cross-AZ traffic

**Resolution:**
1. Consider VPC endpoints to bypass NAT Gateway
2. Ensure VPC Link and ALB are in same AZs
3. Monitor VPC Link CloudWatch metrics

## Switching Between Modes

### From Public to Private

1. Update `terraform.tfvars`:
   ```hcl
   enable_private_deployment = true
   ```

2. Review changes:
   ```bash
   terraform plan
   ```

3. Apply changes:
   ```bash
   terraform apply
   ```

**Impact:**
- ALB will be recreated (brief downtime)
- New VPC Link will be created
- DNS propagation time (~1-2 minutes)

### From Private to Public

1. Update `terraform.tfvars`:
   ```hcl
   enable_private_deployment = false
   ```

2. Review and apply changes

**Impact:**
- ALB will be recreated with public IPs
- VPC Link will be destroyed
- API Gateway will connect directly to public ALB

## Best Practices

1. **Use VPC Endpoints:** Reduce NAT Gateway costs and improve security
2. **Monitor VPC Link:** Set up CloudWatch alarms for availability
3. **Test Thoroughly:** Verify all API calls work correctly after deployment
4. **Document CIDR:** Keep track of VPC CIDR blocks for security group rules
5. **Plan Maintenance:** VPC Link updates may require brief downtime

## Security Checklist

- [ ] Private subnets have NAT Gateway access
- [ ] VPC DNS settings enabled
- [ ] Security groups properly configured
- [ ] ALB is internal (no public IPs)
- [ ] VPC Link is in AVAILABLE state
- [ ] API Gateway connects via VPC Link
- [ ] Target group health checks passing
- [ ] CloudWatch logs flowing correctly
- [ ] Application accessible via API Gateway endpoint
- [ ] No direct access to ALB from internet

## Additional Resources

- [AWS VPC Link Documentation](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vpc-links.html)
- [Internal ALB Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)

