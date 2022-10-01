locals {
  tags = merge(
    var.tags,
    {
      Terraform = "true"
    }
  )
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
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${module.s3_bucket.s3_bucket_arn}/*",
    ]
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/kms/aws/1.1.0
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "1.1.0"

  # Grants
  grants = {
    lambda = {
      grantee_principal = module.lambda_s3_write.lambda_role_arn
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

  bucket_prefix = "${random_pet.this.id}-"
  force_destroy = true

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

  # Bucket policy
  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket.json

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.kms.key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/4.33.0/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "bucket" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [module.lambda_s3_write.lambda_role_arn]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${module.s3_bucket.s3_bucket_arn}/*",
    ]
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws/4.0.2
module "lambda_s3_write" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.0.2"

  description = "Lambda demonstrating writes to an S3 bucket from within a VPC without Internet access"

  function_name = random_pet.this.id
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "${path.module}/fixtures/python3.8-app"

  environment_variables = {
    BUCKET_NAME = module.s3_bucket.s3_bucket_id
    REGION_NAME = var.region
  }

  # Let the module create a role for us; we don't attach any extra policy for S3 writes as that's allowed by the bucket policy
  create_role                   = true
  attach_cloudwatch_logs_policy = true
  attach_network_policy         = true

  vpc_security_group_ids = [module.security_group_lambda.security_group_id]
  vpc_subnet_ids         = module.vpc.private_subnets
}

# https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/4.13.1
module "security_group_lambda" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.1"

  name        = random_pet.this.id
  description = "Security Group for Lambda Egress"

  vpc_id = module.vpc.vpc_id

  egress_cidr_blocks      = []
  egress_ipv6_cidr_blocks = []

  # Prefix list ids to use in all egress rules in this module
  egress_prefix_list_ids = [module.vpc_endpoints.endpoints["s3"]["prefix_list_id"]]

  egress_rules = ["https-443-tcp"]
}
