# VPC Configuration Guide

This document explains how to configure the Terraform deployment to use either a new VPC or an existing VPC with existing subnets.

## Default Behavior (New VPC)

By default, the Terraform scripts will create:
- A new VPC with CIDR block `10.0.0.0/16`
- 2 public subnets in different availability zones
- 2 private subnets in different availability zones
- Internet Gateway for public subnet access
- NAT Gateways in each public subnet for private subnet internet access
- Route tables and associations

No additional configuration is needed for this default behavior.

## Using an Existing VPC

If you want to deploy the infrastructure into an existing VPC with existing subnets, you can specify the VPC ID and subnet IDs in your `terraform.tfvars` file.

### Requirements

When using an existing VPC and subnets, you must ensure:

1. **VPC Requirements:**
   - DNS hostnames and DNS support should be enabled
   - Valid VPC ID format: `vpc-xxxxxxxxx`

2. **Public Subnets:**
   - Must provide at least 2 public subnet IDs
   - Subnets must be in different availability zones
   - Must have routes to an Internet Gateway for the Application Load Balancer

3. **Private Subnets:**
   - Must provide at least 2 private subnet IDs
   - Subnets must be in different availability zones
   - Should have routes to NAT Gateways or NAT Instances for ECS task internet access

### Configuration

Add the following variables to your `terraform.tfvars` file:

```hcl
# Use existing VPC
existing_vpc_id = "vpc-0123456789abcdef0"

# Specify existing public subnets (for ALB)
existing_public_subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-0123456789abcdef1"
]

# Specify existing private subnets (for ECS tasks)
existing_private_subnet_ids = [
  "subnet-0123456789abcdef2",
  "subnet-0123456789abcdef3"
]
```

### How It Works

The Terraform configuration uses conditional logic to determine whether to create or reference networking resources:

1. **When `existing_vpc_id` is empty (default):**
   - Creates a new VPC, subnets, internet gateway, NAT gateways, and route tables
   - All networking infrastructure is managed by Terraform

2. **When `existing_vpc_id` is provided:**
   - Skips creation of VPC and subnet resources
   - Uses the provided VPC and subnet IDs for all resources
   - Security groups and other resources are created in the existing VPC
   - No changes are made to existing route tables or gateways

### Resource Placement

When using existing VPC/subnets, resources are deployed as follows:

- **Public Subnets:** Application Load Balancer (ALB)
- **Private Subnets:** ECS tasks (backend containers)
- **Security Groups:** Created in the existing VPC

### Cost Considerations

**Using a new VPC (default):**
- NAT Gateway costs: ~$0.045/hour per AZ + data transfer charges
- 2 NAT Gateways = ~$65/month (before data transfer)

**Using an existing VPC:**
- No additional NAT Gateway costs if already configured
- Potential cost savings if existing infrastructure is already in place
- Leverages existing networking investments

### Validation

After configuring the variables, validate your configuration:

```bash
cd terraform
terraform init
terraform validate
terraform plan
```

The plan output will show whether new networking resources will be created or if existing resources will be used.

### Example: Complete Configuration

```hcl
# terraform.tfvars

# Basic configuration
aws_region      = "us-east-1"
project_name    = "ai-dms-chatbot"
resource_suffix = "prod"

# Use existing VPC
existing_vpc_id = "vpc-0a1b2c3d4e5f67890"
existing_public_subnet_ids = [
  "subnet-public1a",
  "subnet-public1b"
]
existing_private_subnet_ids = [
  "subnet-private1a",
  "subnet-private1b"
]

# Other configurations...
dynamodb_table_name = "my-dms-table"
s3_bucket_names     = ["my-data-bucket"]
```

## Troubleshooting

### Error: Subnets must be in different availability zones

Ensure that your public subnets are in at least 2 different AZs, and private subnets are also in at least 2 different AZs.

### Error: Cannot reach internet from ECS tasks

Verify that private subnets have routes to NAT Gateways or NAT Instances for outbound internet access.

### Error: ALB health checks failing

Ensure public subnets have routes to an Internet Gateway and that security groups allow traffic on port 80.

## Switching Between Configurations

To switch from using an existing VPC to creating a new one (or vice versa):

1. Update your `terraform.tfvars` file
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes

**Warning:** Switching between configurations will destroy and recreate networking resources, which may cause downtime.
