import boto3
import botocore.config
import os
from uuid import uuid4

bucketName = os.environ['BUCKET_NAME']
regionName = os.environ['REGION_NAME']

def lambda_handler(event, context):
    # Using S3 VPC Endpoint requires 'path' style addressing, to avoid global url resolution
    # Create client per: http://boto3.readthedocs.io/en/latest/guide/s3.html
    client = boto3.client('s3', regionName, config=botocore.config.Config(s3={'addressing_style': 'path'}))
    resp = client.put_object(
       Bucket=bucketName,
       Key=str(uuid4()),
       Body=bytearray("Hello World", 'utf-8')
    )
    print(resp)
