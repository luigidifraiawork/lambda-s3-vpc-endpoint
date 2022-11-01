locals {
  tags = merge(
    var.tags,
    {
      Terraform = "true"
    }
  )
  spoke1_vpc_cidr = cidrsubnet(var.vpc_cidr, 8, 0)
  spoke2_vpc_cidr = cidrsubnet(var.vpc_cidr, 8, 1)
  ss_vpc_cidr     = cidrsubnet(var.vpc_cidr, 8, 50)
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

data "aws_availability_zones" "available" {}

locals {
  azs = slice(sort(data.aws_availability_zones.available.names), 0, var.az_count)
}

################################################################################
# Supporting Resources
################################################################################

resource "random_pet" "this" {
  length = 2
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/3.16.0
module "ss_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "${random_pet.this.id}-ss"
  cidr = local.ss_vpc_cidr

  azs           = local.azs
  intra_subnets = [for k, v in local.azs : cidrsubnet(local.ss_vpc_cidr, 8, k)]
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/3.16.0/submodules/vpc-endpoints
module "ss_vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 3.0"

  vpc_id = module.ss_vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.ss_vpc.intra_route_table_ids
      policy          = data.aws_iam_policy_document.endpoint.json
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/4.33.0/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "endpoint" {
  statement {
    sid = "RestrictBucketAccessToIAMRole"

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

    # See https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html#edit-vpc-endpoint-policy-s3
    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [module.lambda_s3_write.lambda_role_arn]
    }
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/kms/aws/1.1.0
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.0"

  description = "S3 encryption key"

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
  version = "~> 3.0"

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
    sid = "RestrictBucketAccessToIAMRole"

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

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/3.16.0
module "spoke1_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "${random_pet.this.id}-spoke1"
  cidr = local.spoke1_vpc_cidr

  azs           = local.azs
  intra_subnets = [for k, v in local.azs : cidrsubnet(local.spoke1_vpc_cidr, 8, k)]
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/3.16.0
module "spoke2_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "${random_pet.this.id}-spoke2"
  cidr = local.spoke2_vpc_cidr

  azs           = local.azs
  intra_subnets = [for k, v in local.azs : cidrsubnet(local.spoke2_vpc_cidr, 8, k)]
}

# https://registry.terraform.io/modules/terraform-aws-modules/transit-gateway/aws/2.8.0
module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "~> 2.8"

  name = random_pet.this.id

  enable_auto_accept_shared_attachments  = true
  enable_default_route_table_association = false
  enable_default_route_table_propagation = false
}

resource "aws_route" "ss_default" {
  count                  = var.az_count
  route_table_id         = module.ss_vpc.intra_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "spoke1_default" {
  count                  = var.az_count
  route_table_id         = module.spoke1_vpc.intra_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "spoke2_default" {
  count                  = var.az_count
  route_table_id         = module.spoke2_vpc.intra_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.ec2_transit_gateway_id
}

resource "aws_ec2_transit_gateway_route_table" "ss" {
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
}

resource "aws_ec2_transit_gateway_route_table" "spoke1" {
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
}

resource "aws_ec2_transit_gateway_route_table" "spoke2" {
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "ss" {
  subnet_ids         = module.ss_vpc.intra_subnets
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = module.ss_vpc.vpc_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke1" {
  subnet_ids         = module.spoke1_vpc.intra_subnets
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = module.spoke1_vpc.vpc_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke2" {
  subnet_ids         = module.spoke2_vpc.intra_subnets
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = module.spoke2_vpc.vpc_id
}

resource "aws_ec2_transit_gateway_route_table_association" "ss" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.ss.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ss.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke1.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke2.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "ss_to_spoke1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ss.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "ss_to_spoke2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.ss.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke1_to_ss" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.ss.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke1.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke2_to_ss" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.ss.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke2.id
}

################################################################################
# Lambda Module
################################################################################

# https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws/4.0.2
module "lambda_s3_write" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 4.0"

  description = "Lambda demonstrating writes to an S3 bucket from within a VPC without Internet access"

  function_name = random_pet.this.id
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "${path.module}/fixtures/python3.8-app"

  environment_variables = {
    BUCKET_NAME = module.s3_bucket.s3_bucket_id
    REGION_NAME = var.region
  }

  # Let the module create a role for us
  create_role                   = true
  attach_cloudwatch_logs_policy = true
  attach_network_policy         = true

  # There's no need to attach any extra permission for S3 writes as that's added by the bucket policy when a session is created
  # See https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html

  vpc_security_group_ids = [module.security_group_lambda.security_group_id]
  vpc_subnet_ids         = module.spoke1_vpc.intra_subnets
}

# https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/4.13.1
module "security_group_lambda" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = random_pet.this.id
  description = "Security Group for Lambda Egress"

  vpc_id = module.spoke1_vpc.vpc_id

  #egress_cidr_blocks      = []
  egress_ipv6_cidr_blocks = []

  # Prefix list ids to use in all egress rules in this module
  #egress_prefix_list_ids = [module.ss_vpc_endpoints.endpoints["s3"]["prefix_list_id"]]

  egress_rules = ["https-443-tcp"]
}
