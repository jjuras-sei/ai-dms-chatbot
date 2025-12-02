output "cloudfront_distribution_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "s3_bucket_name" {
  description = "S3 bucket name for frontend hosting"
  value       = aws_s3_bucket.frontend.id
}

output "api_gateway_url" {
  description = "API Gateway endpoint URL (disabled when disable_execute_api_endpoint is true)"
  value       = (var.disable_execute_api_endpoint != null ? var.disable_execute_api_endpoint : var.enable_private_api) ? "API Gateway public endpoint is disabled. Access via VPC endpoint." : aws_apigatewayv2_api.backend.api_endpoint
}

output "api_gateway_vpc_endpoint_dns" {
  description = "VPC Endpoint DNS names for API Gateway (only available when private API is enabled)"
  value = var.enable_private_api ? (
    local.use_existing_api_gateway_vpc_endpoint ? 
      ["Using existing VPC endpoint: ${var.existing_api_gateway_vpc_endpoint_id}"] : 
      aws_vpc_endpoint.api_gateway[0].dns_entry[*].dns_name
  ) : []
}

output "vpc_endpoint_id" {
  description = "VPC Endpoint ID for API Gateway (only available when private API is enabled)"
  value = var.enable_private_api ? (
    local.use_existing_api_gateway_vpc_endpoint ? 
      var.existing_api_gateway_vpc_endpoint_id : 
      aws_vpc_endpoint.api_gateway[0].id
  ) : null
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.backend.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for backend Docker image"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.backend.name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name configured for the application"
  value       = var.dynamodb_table_name
}

output "s3_data_bucket_names" {
  description = "List of S3 data bucket names configured for the application"
  value       = var.s3_bucket_names
}
