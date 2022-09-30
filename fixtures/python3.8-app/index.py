import boto3
import botocore.config
import os
from uuid import uuid4

BUCKET_NAME = os.environ['BucketName']
REGION_NAME = os.environ['RegionName']

def lambda_handler(event, context):
    # Using S3 VPC Endpoint requires 'path' style addressing, to avoid global url resolution
    # Create client per: http://boto3.readthedocs.io/en/latest/guide/s3.html
    client = boto3.client('s3', REGION_NAME, config=botocore.config.Config(s3={'addressing_style':'path'}))
    resp = client.put_object(
       Bucket=BUCKET_NAME,
       Key=str(uuid4()),
       Body=bytearray("Hello World", 'utf-8')
    )
    print(resp)
