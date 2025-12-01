variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "ai-dms-chatbot"
}

variable "resource_suffix" {
  description = "Suffix to append to resource names for uniqueness"
  type        = string
  default     = "dev"
}

variable "bedrock_model_id" {
  description = "AWS Bedrock model ID to use for the chatbot"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
  
  validation {
    condition = contains([
      "anthropic.claude-3-sonnet-20240229-v1:0",
      "anthropic.claude-3-haiku-20240307-v1:0",
      "anthropic.claude-v2:1",
      "anthropic.claude-v2",
      "anthropic.claude-instant-v1",
      "meta.llama2-13b-chat-v1",
      "meta.llama2-70b-chat-v1",
      "amazon.titan-text-express-v1"
    ], var.bedrock_model_id)
    error_message = "Invalid Bedrock model ID. Please use a supported model."
  }
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS task (1024 = 1 vCPU)"
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "Memory for the ECS task in MB"
  type        = string
  default     = "1024"
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table to query"
  type        = string
  default     = ""
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names that the application can access"
  type        = list(string)
  default     = []
}

variable "enable_error_viewing" {
  description = "Enable detailed error viewing in the frontend (useful for debugging)"
  type        = bool
  default     = false
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs. Set to null for indefinite retention (logs never expire). Common values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653"
  type        = number
  default     = 7
}

# Networking - Existing VPC/Subnet Configuration
variable "existing_vpc_id" {
  description = "ID of an existing VPC to use. If not provided, a new VPC will be created."
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "List of existing public subnet IDs to use. Required if existing_vpc_id is provided. Must have at least 2 subnets in different availability zones."
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "List of existing private subnet IDs to use. Required if existing_vpc_id is provided. Must have at least 2 subnets in different availability zones."
  type        = list(string)
  default     = []
}

# Deployment Mode Configuration
variable "enable_private_deployment" {
  description = "Enable private deployment mode. When true, the ALB will be internal and API Gateway will use VPC Link. When false, the ALB will be internet-facing (public)."
  type        = bool
  default     = false
}

variable "enable_private_api" {
  description = "Enable fully private API Gateway. When true, API Gateway will only be accessible from within the VPC via VPC endpoint. Requires enable_private_deployment to be true."
  type        = bool
  default     = false
}

variable "disable_execute_api_endpoint" {
  description = "Disable the default execute-api endpoint for API Gateway. When null (default), this will be set to the value of enable_private_api. Set to true to force disable the endpoint, or false to force enable it."
  type        = bool
  default     = null
}

variable "existing_api_gateway_vpc_endpoint_id" {
  description = "ID of an existing VPC Endpoint for API Gateway (execute-api). If not provided and enable_private_api is true, a new VPC endpoint will be created."
  type        = string
  default     = ""
}
