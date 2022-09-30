# lambda-s3-vpc-endpoint
Creates a VPC with S3 endpoint, showing that a Lambda function in such VPC can reach S3 without Internet access.

Based on a CloudFormation [project](https://github.com/gford1000-aws/lambda_s3_access_using_vpc_endpoint) published in GitHub.

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

Retrieve the prefix list ID for S3 in the region:
```commandline
aws ec2 describe-prefix-lists
```

Ensure that you pass the value to Terraform:
```commandline
export TF_VAR_s3_prefix_list_id=<prefix list ID>
```

Deploy with:
```commandline
terraform init
terraform plan
terraform apply -auto-approve
```
