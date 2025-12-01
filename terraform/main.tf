terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Local variables for conditional logic
locals {
  use_existing_vpc                      = var.existing_vpc_id != ""
  use_existing_api_gateway_vpc_endpoint = var.existing_api_gateway_vpc_endpoint_id != ""
  vpc_id                                = local.use_existing_vpc ? var.existing_vpc_id : aws_vpc.main[0].id
  vpc_cidr_block                        = local.use_existing_vpc ? data.aws_vpc.existing[0].cidr_block : aws_vpc.main[0].cidr_block
  public_subnet_ids                     = local.use_existing_vpc ? var.existing_public_subnet_ids : aws_subnet.public[*].id
  private_subnet_ids                    = local.use_existing_vpc ? var.existing_private_subnet_ids : aws_subnet.private[*].id
}

# Data sources for existing VPC and subnets (when provided)
data "aws_vpc" "existing" {
  count = local.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

data "aws_subnet" "existing_public" {
  count = local.use_existing_vpc ? length(var.existing_public_subnet_ids) : 0
  id    = var.existing_public_subnet_ids[count.index]
}

data "aws_subnet" "existing_private" {
  count = local.use_existing_vpc ? length(var.existing_private_subnet_ids) : 0
  id    = var.existing_private_subnet_ids[count.index]
}

# S3 bucket for frontend static hosting
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${var.resource_suffix}"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac-${var.resource_suffix}"
  description                       = "OAC for frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy - allow CloudFront OAC only
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# CloudFront distribution for frontend
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }
}

# VPC and Networking (only created if existing_vpc_id is not provided)
resource "aws_vpc" "main" {
  count                = local.use_existing_vpc ? 0 : 1
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

}

resource "aws_subnet" "public" {
  count                   = local.use_existing_vpc ? 0 : 2
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

}

resource "aws_subnet" "private" {
  count             = local.use_existing_vpc ? 0 : 2
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

}

resource "aws_internet_gateway" "main" {
  count  = local.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.main[0].id

}

resource "aws_eip" "nat" {
  count  = local.use_existing_vpc ? 0 : 2
  domain = "vpc"


  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = local.use_existing_vpc ? 0 : 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id


  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  count  = local.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

}

resource "aws_route_table" "private" {
  count  = local.use_existing_vpc ? 0 : 2
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

}

resource "aws_route_table_association" "public" {
  count          = local.use_existing_vpc ? 0 : 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count          = local.use_existing_vpc ? 0 : 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ECR Repository
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend-${var.resource_suffix}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.resource_suffix}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg-${var.resource_suffix}"
  description = "Allow inbound traffic to ECS tasks from ALB"
  vpc_id      = local.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-exec-role-${var.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role-${var.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

}

# IAM Policy for Bedrock Access
resource "aws_iam_policy" "bedrock_access" {
  name        = "${var.project_name}-bedrock-access-${var.resource_suffix}"
  description = "Policy for accessing AWS Bedrock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for DynamoDB Access
resource "aws_iam_policy" "dynamodb_access" {
  name        = "${var.project_name}-dynamodb-access-${var.resource_suffix}"
  description = "Policy for accessing AWS DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:GetItem",
          "dynamodb:BatchGetItem",
          "dynamodb:DescribeTable"
        ]
        Resource = var.dynamodb_table_name != "" ? [
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.dynamodb_table_name}",
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.dynamodb_table_name}/index/*"
        ] : ["*"]
      }
    ]
  })
}

# IAM Policy for S3 Access (only created if bucket names are specified)
resource "aws_iam_policy" "s3_access" {
  count = length(var.s3_bucket_names) > 0 ? 1 : 0

  name        = "${var.project_name}-s3-access-${var.resource_suffix}"
  description = "Policy for accessing AWS S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          for bucket in var.s3_bucket_names : "arn:aws:s3:::${bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_bedrock" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_dynamodb" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3" {
  count = length(var.s3_bucket_names) > 0 ? 1 : 0

  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access[0].arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend-${var.resource_suffix}"
  retention_in_days = 7

}

# ECS Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend-${var.resource_suffix}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "BEDROCK_MODEL_ID"
          value = var.bedrock_model_id
        },
        {
          name  = "DYNAMODB_TABLE_NAME"
          value = var.dynamodb_table_name
        },
        {
          name  = "ENABLE_ERROR_VIEWING"
          value = tostring(var.enable_error_viewing)
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

}

# ECS Service
resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-svc-${var.resource_suffix}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.backend]

}

# Application Load Balancer
resource "aws_lb" "backend" {
  name               = "${var.project_name}-alb-${var.resource_suffix}"
  internal           = var.enable_private_deployment
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.enable_private_deployment ? local.private_subnet_ids : local.public_subnet_ids

}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg-${var.resource_suffix}"
  description = "Security group for ALB"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = var.enable_private_deployment ? [local.vpc_cidr_block] : ["0.0.0.0/0"]
    description = var.enable_private_deployment ? "Allow HTTP from VPC" : "Allow HTTP from internet"
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = var.enable_private_deployment ? [local.vpc_cidr_block] : ["0.0.0.0/0"]
    description = var.enable_private_deployment ? "Allow HTTPS from VPC" : "Allow HTTPS from internet"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-tg-${var.resource_suffix}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# VPC Link for API Gateway (created when private deployment is enabled)
resource "aws_apigatewayv2_vpc_link" "backend" {
  count              = var.enable_private_deployment ? 1 : 0
  name               = "${var.project_name}-vpc-link-${var.resource_suffix}"
  security_group_ids = [aws_security_group.vpc_link[0].id]
  subnet_ids         = local.private_subnet_ids

}

# Security Group for VPC Link (created when private deployment is enabled)
resource "aws_security_group" "vpc_link" {
  count       = var.enable_private_deployment ? 1 : 0
  name        = "${var.project_name}-vpc-link-sg-${var.resource_suffix}"
  description = "Security group for VPC Link"
  vpc_id      = local.vpc_id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Security Group for API Gateway VPC Endpoint (only created when private API is enabled and no existing endpoint provided)
resource "aws_security_group" "api_gateway_vpc_endpoint" {
  count       = var.enable_private_api && !local.use_existing_api_gateway_vpc_endpoint ? 1 : 0
  name        = "${var.project_name}-apigw-vpce-sg-${var.resource_suffix}"
  description = "Security group for API Gateway VPC Endpoint"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [local.vpc_cidr_block]
    description = "Allow HTTPS from VPC"
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# VPC Endpoint for API Gateway (only created when private API is enabled and no existing endpoint provided)
resource "aws_vpc_endpoint" "api_gateway" {
  count             = var.enable_private_api && !local.use_existing_api_gateway_vpc_endpoint ? 1 : 0
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.execute-api"
  vpc_endpoint_type = "Interface"

  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.api_gateway_vpc_endpoint[0].id]

  private_dns_enabled = true

}

# API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "backend" {
  name          = "${var.project_name}-api-${var.resource_suffix}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  # Disable default endpoint when private API is enabled
  # This forces all traffic through the VPC endpoint
  disable_execute_api_endpoint = var.enable_private_api

}

resource "aws_apigatewayv2_integration" "backend" {
  api_id           = aws_apigatewayv2_api.backend.id
  integration_type = "HTTP_PROXY"
  integration_uri  = var.enable_private_deployment ? aws_lb_listener.backend.arn : "http://${aws_lb.backend.dns_name}"

  integration_method     = "ANY"
  connection_type        = var.enable_private_deployment ? "VPC_LINK" : "INTERNET"
  connection_id          = var.enable_private_deployment ? aws_apigatewayv2_vpc_link.backend[0].id : null
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "backend" {
  api_id    = aws_apigatewayv2_api.backend.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

resource "aws_apigatewayv2_stage" "backend" {
  api_id      = aws_apigatewayv2_api.backend.id
  name        = "$default"
  auto_deploy = true

}

data "aws_availability_zones" "available" {
  state = "available"
}
