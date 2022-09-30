locals {
  tags = {
    Terraform   = "true"
    Environment = "sandbox"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.33.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.3"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.region

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true

  default_tags {
    tags = local.tags
  }
}

resource "random_pet" "this" {
  length = 2
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/3.16.0
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.16.0"

  name = random_pet.this.id
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/3.16.0/submodules/vpc-endpoints
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.16.0"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      policy          = data.aws_iam_policy_document.endpoint.json
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/4.33.0/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "endpoint" {
  statement {
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.s3_bucket.s3_bucket_id}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/kms/aws/1.1.0
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "1.1.0"

  # Grants
  grants = {
    lambda = {
      grantee_principal = module.iam_role_lambda.iam_role_arn
      operations = [
        "GenerateDataKey",
      ]
    }
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/3.4.0
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.4.0"

  force_destroy = true

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.kms.key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws/4.0.2
module "lambda_s3_write" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.0.2"

  function_name = random_pet.this.id
  description   = "Lambda demonstrating writes to an S3 bucket from a VPC without Internet access"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  create_role = false
  lambda_role = module.iam_role_lambda.iam_role_arn

  source_path = "${path.module}/fixtures/python3.8-app"

  environment_variables = {
    BUCKET_NAME = module.s3_bucket.s3_bucket_id
    REGION_NAME = var.region
  }

  vpc_security_group_ids = [module.security_group_lambda.security_group_id]
  vpc_subnet_ids         = module.vpc.private_subnets

  attach_network_policy = true
}

# https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/4.13.1
module "security_group_lambda" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.1"

  name        = random_pet.this.id
  description = "Security Group for Lambda Egress"
  vpc_id      = module.vpc.vpc_id

  # Prefix list ids to use in all egress rules in this module
  egress_prefix_list_ids = [var.s3_prefix_list_id]

  egress_rules = ["all-all"]
}

# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/5.5.0/submodules/iam-assumable-role
module "iam_role_lambda" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.5.0"

  trusted_role_services = [
    "lambda.amazonaws.com",
  ]

  create_role       = true
  role_requires_mfa = false
  role_name         = random_pet.this.id

  custom_role_policy_arns = [
    module.iam_policy_lambda.arn,
    data.aws_iam_policy.lambda_vpc.arn,
  ]
}

# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/5.5.0/submodules/iam-policy
module "iam_policy_lambda" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.5.0"

  name   = random_pet.this.id
  policy = data.aws_iam_policy_document.lambda.json
}

# https://registry.terraform.io/providers/hashicorp/aws/4.33.0/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "lambda" {
  statement {
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.s3_bucket.s3_bucket_id}/*",
    ]
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/4.33.0/docs/resources/iam_policy
data "aws_iam_policy" "lambda_vpc" {
  name = "AWSLambdaVPCAccessExecutionRole"
}
