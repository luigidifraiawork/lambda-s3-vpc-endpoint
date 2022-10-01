# lambda-s3-vpc-endpoint

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
