import boto3
import os
from uuid import uuid4

bucketName = os.environ['BUCKET_NAME']
regionName = os.environ['REGION_NAME']

def lambda_handler(event, context):
    client = boto3.client('s3', regionName)
    resp = client.put_object(
       Bucket=bucketName,
       Key=str(uuid4()),
       Body=bytearray("Hello World", 'utf-8')
    )
    print(resp)
