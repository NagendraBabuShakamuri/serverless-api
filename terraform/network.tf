# resource "aws_vpc" "dev_vpc" {
#   cidr_block = var.cidr_block

#   tags = {
#     Name = "${var.aws_profile}-vpc"
#   }
# }

# data "aws_availability_zones" "all" {
#   state = "available"
# }

# resource "aws_subnet" "private_subnet" {
#   count             = var.private_subnets
#   vpc_id            = aws_vpc.dev_vpc.id
#   cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 1)
#   availability_zone = element(data.aws_availability_zones.all.names, count.index % length(data.aws_availability_zones.all.names))

#   tags = {
#     Name = "${aws_vpc.dev_vpc.id}-Private subnet ${count.index + 1}"
#   }
# }

# resource "aws_route_table" "private_route_table" {
#   vpc_id = aws_vpc.dev_vpc.id
#   tags = {
#     "Name" = "Private-route-table"
#   }
# }

# resource "aws_route_table_association" "private_route_table_association" {
#   count          = var.private_subnets
#   subnet_id      = aws_subnet.private_subnet[count.index].id
#   route_table_id = aws_route_table.private_route_table.id
# }

resource "aws_security_group" "db-sg" {
  name        = "${var.aws_profile}-database-sg"
  description = "Database security group to allow inbound/outbound from the VPC"
#   vpc_id      = aws_vpc.dev_vpc.id
#   depends_on  = [aws_vpc.dev_vpc]
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    # security_groups = [aws_security_group.lambda_sg.id]
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.aws_profile}-database-sg"
  }
}

# resource "aws_security_group" "lambda_sg" {
#     name        = "${var.aws_profile}-lambda-sg"
#     description = "lambda security group to allow inbound/outbound from the VPC"
#     vpc_id      = aws_vpc.dev_vpc.id
#     depends_on  = [aws_vpc.dev_vpc]
# }

# Create a DB subnet group
# resource "aws_db_subnet_group" "private_db_subnet_group" {
#   name = "private_db_subnet_group"
#   subnet_ids = [for s in aws_subnet.private_subnet : s.id]
# }

resource "aws_kms_key" "aurora_kms_key" {
  description = "My Aurora KMS key"
}

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier            = "serverless-cluster"
  engine                        = "aurora-mysql"
  engine_mode                   = "provisioned"
  engine_version                = "8.0.mysql_aurora.3.02.0"
  database_name                 = "webapp"
#   db_subnet_group_name          = aws_db_subnet_group.private_db_subnet_group.name
#   vpc_security_group_ids        = [aws_security_group.db-sg.id]
  master_username               = "admin"
  manage_master_user_password   = true
  storage_encrypted             = true
  master_user_secret_kms_key_id = aws_kms_key.aurora_kms_key.key_id
  skip_final_snapshot = true

#   master_user_secret {
#     secret_arn = aws_secretsmanager_secret_version.master_user_secret.arn
#   }

  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }
}

output "rds_output" {
  value = aws_rds_cluster.aurora_cluster.master_user_secret[0].secret_arn
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_cluster.engine
  engine_version     = aws_rds_cluster.aurora_cluster.engine_version  
  publicly_accessible = true
}

# Generate a random name for the S3 bucket.

resource "random_id" "random" {
  byte_length = 4
}

#Create a private S3 bucket.

resource "aws_s3_bucket" "private_bucket" {
  bucket        = "my-bucket-${random_id.random.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.private_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.private_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.private_bucket.id
  rule {
    id     = "transition_to_standard_ia"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# Create an S3 access policy to the above role.

resource "aws_iam_policy" "S3_policy" {
  name        = "WebAppS3"
  description = "Policy for accessing S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.private_bucket.arn}",
          "${aws_s3_bucket.private_bucket.arn}/*"
        ]
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "aurora_policy" {
    name = "aurora_policy"
    description = "Policy to access aurora instance"

    policy = jsonencode({ 
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "rds-db:connect"
                ],
                "Resource": [
                    "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_rds_cluster.aurora_cluster.id}/${aws_rds_cluster.aurora_cluster.master_username}"
                ]
            }
        ]
    })
}

resource "aws_iam_policy" "lambda_rds_secret_policy" {
  name_prefix = "LambdaRdsSecretPolicy-"

  # Define permissions for accessing the Aurora secret in AWS Secrets Manager
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ],
        Effect = "Allow",
        Resource = aws_rds_cluster.aurora_cluster.master_user_secret[0].secret_arn,
      },
    ],
  })
}

# Create an IAM Role for S3 Access.

resource "aws_iam_role" "lambda_s3_aurora" {
  name = "lambda-s3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_eni_policy" {
    name = "eni_policy"
    description = "Policy to access EC2 ENI in VPC"
    policy = jsonencode({ 
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:CreateNetworkInterface",
                    "ec2:DescribeNetworkInterfaces",
                    "ec2:DeleteNetworkInterface"
                ],
                "Resource": "*"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_s3_aurora.name
}

# Attach the policy to the created role.

resource "aws_iam_role_policy_attachment" "role_attachment" {
  for_each = {
    "s3": aws_iam_policy.S3_policy.arn,
    "aurora": aws_iam_policy.aurora_policy.arn,
    "eni": aws_iam_policy.lambda_eni_policy.arn,
    "secret": aws_iam_policy.lambda_rds_secret_policy.arn
  }
  policy_arn = each.value
  role       = aws_iam_role.lambda_s3_aurora.name
}

data "aws_secretsmanager_secret_version" "by-arn" {
  secret_id = aws_rds_cluster.aurora_cluster.master_user_secret[0].secret_arn
}

output "secret" {
  value = data.aws_secretsmanager_secret_version.by-arn.secret_string
  sensitive = true
}

resource "aws_lambda_function" "api_lambda" {
  filename      = "~/Documents/app.zip"
  function_name = "serverless_api"
  role          = aws_iam_role.lambda_s3_aurora.arn
  handler       = "index.handler"
  source_code_hash = filebase64sha256("~/Documents/app.zip")

  runtime = "nodejs16.x"

#   vpc_config {
#     subnet_ids         = [for s in aws_subnet.private_subnet : s.id]
#     security_group_ids = [aws_security_group.lambda_sg.id]
#   }

  environment {
    variables = {
      ENVIRONMENT = "lambda"
      S3_BUCKET = aws_s3_bucket.private_bucket.id
      REGION = var.region
      USER_NAME = aws_rds_cluster.aurora_cluster.master_username
      HOST = aws_rds_cluster.aurora_cluster.endpoint
      DATABASE = aws_rds_cluster.aurora_cluster.database_name
      SECRET = jsondecode(data.aws_secretsmanager_secret_version.by-arn.secret_string)["password"]
    }
  }
}

resource "aws_lambda_permission" "permissions" {
  for_each = var.lambda_permission_arns
  statement_id  = each.key
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*${each.value}"
}

resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "Inventory-Management-API"
  description = "Inventory Management API"
}

resource "aws_api_gateway_resource" "healthz" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "healthz"
}

resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "post_user" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "user"
}

resource "aws_api_gateway_resource" "user" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_resource.post_user.id
  path_part   = "{userId}"
}

resource "aws_api_gateway_resource" "post_product" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "product"
}

resource "aws_api_gateway_resource" "product" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_resource.post_product.id
  path_part   = "{productId}"
}

resource "aws_api_gateway_resource" "product_images" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_resource.product.id
  path_part   = "image"
}

resource "aws_api_gateway_resource" "product_image" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_resource.product_images.id
  path_part   = "{imageId}"
}

resource "aws_api_gateway_method" "healthz" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.healthz.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_user" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.user.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_user" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.post_user.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "put_user" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.user.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_product" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.product.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_product" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.post_product.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "put_product" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.product.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "patch_product" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.product.id
  http_method   = "PATCH"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "delete_product" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.product.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_product_images" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.product_images.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_product_image" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.product_images.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_product_image" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.product_image.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "delete_product_image" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.product_image.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "healthz_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.healthz.id
  http_method          = aws_api_gateway_method.healthz.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "get_user_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.user.id
  http_method          = aws_api_gateway_method.get_user.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "post_user_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.post_user.id
  http_method          = aws_api_gateway_method.post_user.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "put_user_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.user.id
  http_method          = aws_api_gateway_method.put_user.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "get_product_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.product.id
  http_method          = aws_api_gateway_method.get_product.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "post_product_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.post_product.id
  http_method          = aws_api_gateway_method.post_product.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "put_product_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.product.id
  http_method          = aws_api_gateway_method.put_product.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "patch_product_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.product.id
  http_method          = aws_api_gateway_method.patch_product.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "delete_product_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.product.id
  http_method          = aws_api_gateway_method.delete_product.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "get_product_images_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.product_images.id
  http_method          = aws_api_gateway_method.get_product_images.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "get_product_image_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.product_image.id
  http_method          = aws_api_gateway_method.get_product_image.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "post_product_image_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.product_images.id
  http_method          = aws_api_gateway_method.post_product_image.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "delete_product_image_integration" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.product_image.id
  http_method          = aws_api_gateway_method.delete_product_image.http_method
  integration_http_method = "POST"
  type                = "AWS_PROXY"
  uri                 = aws_lambda_function.api_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "my_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "DEV"
}