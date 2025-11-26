# Fully Private API Gateway Guide

This document explains how to configure the API Gateway to be fully private, accessible only from within the VPC with no public internet access.

## Overview

The `enable_private_api` mode makes the API Gateway completely private by:
1. Creating a VPC endpoint for API Gateway (execute-api)
2. Disabling the public API Gateway endpoint
3. Forcing all API traffic through the VPC endpoint

This is the most restrictive security posture, suitable for highly sensitive environments.

## Architecture Comparison

### Standard Public Mode
```
Internet → API Gateway (Public) → ALB (Public) → ECS (Private)
```

### Private Deployment Mode
```
Internet → API Gateway (Public) → VPC Link → ALB (Private) → ECS (Private)
```

### Fully Private API Mode
```
VPC Only → VPC Endpoint → API Gateway (No Public Endpoint) → VPC Link → ALB (Private) → ECS (Private)
```

## Key Features

- **No Public Internet Access**: API Gateway has no public endpoint
- **VPC Endpoint Only**: All API calls must go through VPC endpoint
- **Enhanced Security**: Zero exposure to public internet
- **Compliance Ready**: Meets strictest security requirements

## Configuration

### Prerequisites

**Required:**
- `enable_private_deployment = true` (must be enabled first)
- VPC with DNS support enabled
- VPC with DNS hostnames enabled
- Private subnets with NAT Gateway access

### Enable Fully Private API

Add to your `terraform.tfvars`:

```hcl
# Enable private deployment (required)
enable_private_deployment = true

# Enable fully private API
enable_private_api = true
```

### Complete Example

```hcl
# terraform.tfvars

aws_region      = "us-east-1"
project_name    = "ai-dms-chatbot"
resource_suffix = "prod"

# Network configuration
existing_vpc_id = "vpc-0123456789abcdef0"
existing_public_subnet_ids = [
  "subnet-pub-1a",
  "subnet-pub-1b"
]
existing_private_subnet_ids = [
  "subnet-priv-1a",
  "subnet-priv-1b"
]

# Enable fully private mode
enable_private_deployment = true
enable_private_api        = true

# Other configurations
dynamodb_table_name = "my-dms-table"
s3_bucket_names     = ["my-data-bucket"]
```

## Infrastructure Components

### VPC Endpoint for API Gateway
- **Service**: `com.amazonaws.${region}.execute-api`
- **Type**: Interface endpoint
- **Deployment**: Private subnets (2+ AZs)
- **DNS**: Private DNS enabled

### Security Groups

**API Gateway VPC Endpoint Security Group:**
- Ingress: Port 443 from VPC CIDR
- Egress: All traffic
- Purpose: Control access to VPC endpoint

### API Gateway Configuration
- **Public Endpoint**: Disabled (`disable_execute_api_endpoint = true`)
- **Access**: VPC endpoint only
- **Integration**: VPC Link to internal ALB

## Access Methods

### From Within VPC

Resources within the VPC can access the API using the VPC endpoint DNS:

```bash
# Using VPC endpoint DNS (auto-resolved within VPC)
curl https://${API_ID}.execute-api.${REGION}.amazonaws.com/

# The VPC endpoint automatically intercepts execute-api calls
```

### From EC2 Instance

```bash
# Example from EC2 instance in the same VPC
curl -X POST https://abc123.execute-api.us-east-1.amazonaws.com/ \
  -H "Content-Type: application/json" \
  -d '{"query": "What is the status?"}'
```

### From Lambda in VPC

```python
import boto3
import requests

# Lambda function must be in the same VPC with access to private subnets
def lambda_handler(event, context):
    api_url = "https://abc123.execute-api.us-east-1.amazonaws.com/"
    
    response = requests.post(
        api_url,
        json={"query": "What is the status?"}
    )
    
    return {
        'statusCode': 200,
        'body': response.text
    }
```

### From On-Premises via VPN/Direct Connect

```bash
# Requires VPN or Direct Connect to VPC
curl https://${API_ID}.execute-api.${REGION}.amazonaws.com/
```

## Cost Considerations

### Additional Costs

1. **VPC Endpoint for API Gateway**:
   - ~$0.01/hour per AZ (~$7.50/month per AZ)
   - 2 AZs = ~$15/month
   - Data processing: ~$0.01/GB

2. **VPC Link** (from private deployment):
   - ~$0.01/hour (~$7.50/month)

### Total Additional Cost
- **Fully Private API Mode**: ~$22-25/month additional
- Compare to standard public mode: $0 additional
- Cost is minimal for enhanced security

## Deployment Steps

### 1. Ensure Prerequisites

```bash
# Verify VPC DNS settings
aws ec2 describe-vpc-attribute \
  --vpc-id vpc-xxxxx \
  --attribute enableDnsSupport

aws ec2 describe-vpc-attribute \
  --vpc-id vpc-xxxxx \
  --attribute enableDnsHostnames
```

### 2. Configure Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars:
# enable_private_deployment = true
# enable_private_api = true
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Verify Deployment

```bash
# Check VPC endpoint status
terraform output vpc_endpoint_id

# Verify endpoint is available
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids $(terraform output -raw vpc_endpoint_id)
```

### 5. Test Access

From an EC2 instance in the VPC:

```bash
# Get API ID from outputs
API_ID=$(terraform output -raw api_gateway_url | grep -oP '(?<=https://)[^.]+')

# Test API access
curl https://${API_ID}.execute-api.us-east-1.amazonaws.com/health
```

## Security Considerations

### Benefits

1. **Zero Public Exposure**: API has no public internet presence
2. **Network Isolation**: All traffic stays within AWS network
3. **Compliance**: Meets strict regulatory requirements
4. **Reduced Attack Surface**: No DDoS or internet-based attacks
5. **Fine-Grained Access**: Security groups control VPC endpoint access

### Access Control

**VPC Endpoint Security Group:**
```hcl
# Only allow HTTPS from specific sources within VPC
ingress {
  protocol    = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
}
```

**Optional: Restrict to specific subnets:**
```hcl
ingress {
  protocol    = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_blocks = [
    "10.0.1.0/24",  # App subnet 1
    "10.0.2.0/24"   # App subnet 2
  ]
}
```

## Monitoring

### CloudWatch Metrics

Monitor VPC endpoint usage:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/VPC \
  --metric-name BytesTransferred \
  --dimensions Name=VpcEndpointId,Value=vpce-xxxxx \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### VPC Flow Logs

Enable flow logs for VPC endpoint monitoring:
```hcl
resource "aws_flow_log" "vpc_endpoint" {
  vpc_id          = local.vpc_id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn    = aws_iam_role.flow_logs.arn
}
```

## Troubleshooting

### Cannot Access API from VPC

**Symptoms**: Connection timeout or DNS resolution failure

**Checks**:
1. Verify VPC endpoint status is "available"
   ```bash
   aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxxxx
   ```

2. Check VPC DNS settings are enabled
   ```bash
   aws ec2 describe-vpc-attribute --vpc-id vpc-xxxxx --attribute enableDnsSupport
   aws ec2 describe-vpc-attribute --vpc-id vpc-xxxxx --attribute enableDnsHostnames
   ```

3. Verify security group allows port 443
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

4. Test DNS resolution from within VPC
   ```bash
   nslookup ${API_ID}.execute-api.${REGION}.amazonaws.com
   ```

### VPC Endpoint Shows "Failed" Status

**Causes**:
- Insufficient IP addresses in subnet
- Security group misconfiguration
- Service not available in subnet AZ

**Resolution**:
1. Check subnet has available IPs
2. Verify security group allows egress
3. Ensure subnets are in supported AZs

### High Latency

**Causes**:
- Cross-AZ traffic
- NAT Gateway bottleneck

**Solutions**:
1. Ensure VPC endpoint in same AZs as applications
2. Use VPC endpoints for other AWS services (reduce NAT traffic)
3. Monitor VPC endpoint metrics

### Frontend Cannot Reach API

**Important**: The frontend (CloudFront/Browser) cannot directly access a fully private API.

**Solutions**:

1. **Option A**: Keep API Gateway public, use WAF for security
   ```hcl
   enable_private_deployment = true
   enable_private_api        = false  # Keep API accessible from internet
   ```

2. **Option B**: Deploy frontend in VPC with VPN access
   - Host frontend on EC2/ALB behind VPN
   - Users connect via VPN to access application

3. **Option C**: Use API Gateway with resource policy
   - Keep public endpoint but restrict by IP
   - Not covered in this configuration

## Best Practices

1. **Enable VPC Flow Logs**: Monitor all VPC endpoint traffic
2. **Use PrivateLink for AWS Services**: Reduce NAT Gateway costs
3. **Implement Security Groups**: Restrict VPC endpoint access
4. **Enable CloudWatch Alarms**: Alert on endpoint issues
5. **Document Access Patterns**: Clear documentation for developers
6. **Test Thoroughly**: Verify all access patterns work

## Migration Guide

### From Public to Fully Private

1. **Backup current state**
   ```bash
   terraform state pull > terraform.tfstate.backup
   ```

2. **Update configuration**
   ```hcl
   enable_private_deployment = true
   enable_private_api        = true
   ```

3. **Apply changes**
   ```bash
   terraform plan  # Review changes
   terraform apply
   ```

4. **Update applications**: Change API endpoint URLs if needed

5. **Test access**: Verify from VPC resources

### Rollback Procedure

```bash
# Revert configuration
enable_private_api = false

# Apply changes
terraform apply

# Public endpoint will be re-enabled
```

## Use Cases

### Ideal For:
- Internal applications only
- Corporate intranets
- Compliance-heavy industries (healthcare, finance)
- Government applications
- High-security environments

### Not Suitable For:
- Public-facing applications
- Mobile apps (unless via VPN)
- Third-party integrations
- Applications requiring public API access

## Additional Resources

- [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [API Gateway Private APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-private-apis.html)
- [VPC Endpoint Services](https://docs.aws.amazon.com/vpc/latest/privatelink/endpoint-services-overview.html)
