variable "region" {
  description = "Name of the region to deploy to"
  default     = "us-east-1"
}

variable "s3_prefix_list_id" {
  description = "Prefix list ID for S3 in the deployment region, as returned by `aws ec2 describe-prefix-lists`"
  default     = "pl-63a5400a"
}
