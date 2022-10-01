# Lambda access to S3 via VPC Endpoint

The material provided in this repository creates a VPC with an S3 Gateway Endpoint, showing that a Lambda function attached to the VPC can write objects to an S3 bucket without Internet access.

The material *explicitly* avoids using atomic resources defined in the AWS provider. Instead, it uses *exclusively* AWS modules and submodules managed by [Anton Babenko](https://registry.terraform.io/namespaces/antonbabenko) on the Hashicorp Terraform Registry.

Based on a [CloudFormation project](https://github.com/gford1000-aws/lambda_s3_access_using_vpc_endpoint) published in GitHub, updated and rationalised.

## Deployment

Set up authentication details to your Sandbox (e.g. *A Cloud Guru*) with:
```commandline
export AWS_ACCESS_KEY_ID=AKIAZR3FF5EXAMPLEID
export AWS_SECRET_ACCESS_KEY=k9eabHZx0Kq0utFZ2u20Ymo1I7zaWEXAMPLEKEY
export AWS_DEFAULT_REGION=us-east-1
```

Ensure the above are correct by running:
```commandline
aws sts get-caller-identity
```

The output should look as per below:
```commandline
{
    "UserId": "AIDAZR3FF5MEXAMPLEID",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/cloud_user"
}
```

Deploy with:
```commandline
terraform init
terraform plan
terraform apply -auto-approve
```

Destroy with:
```commandline
terraform destroy -auto-approve
```

## Known issues
The first deployment attempt will fail with:
```commandline
╷
│ Error: Provider produced inconsistent final plan
│
│ When expanding the plan for module.vpc.aws_vpc.this[0] to include new values learned so far during apply, provider "registry.terraform.io/hashicorp/aws" produced an invalid new value for .tags_all:
│ new element "Name" has appeared.
│
│ This is a bug in the provider, which should be reported in the provider's own issue tracker.
╵
```

Unfortunately, there is no workaround available at the moment, so just issue the apply command again:
```commandline
terraform apply -auto-approve
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.14 |
| aws | >= 4.33 |
| random | >= 3.4 |

## Providers

| Name | Version   |
|------|-----------|
| aws | >= 4.33.0 |
| random | >= 3.4.3  |

## Modules

| Name | Source | Version |
|------|--------|---------|
| kms | terraform-aws-modules/kms/aws | ~> 1.0 |
| lambda_s3_write | terraform-aws-modules/lambda/aws | ~> 4.0 |
| s3_bucket | terraform-aws-modules/s3-bucket/aws | ~> 3.0 |
| security_group_lambda | terraform-aws-modules/security-group/aws | ~> 4.0 |
| vpc | terraform-aws-modules/vpc/aws | ~> 3.0 |
| vpc_endpoints | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | ~> 3.0 |

## Resources

| Name | Type |
|------|------|
| [random_pet.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_iam_policy_document.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| region | Name of the region to deploy to | `string` | `"us-east-1"` | no |
| tags | Default tags to apply to all resources | `map(string)` | <pre>{<br>  "Environment": "sandbox"<br>}</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
