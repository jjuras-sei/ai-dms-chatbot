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
  description = "DynamoDB table name to query"
  type        = string
  default     = ""
}
