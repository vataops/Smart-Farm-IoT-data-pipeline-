import json
import urllib.parse
import boto3
import pandas
s3 = boto3.client('s3')

def hello(event, context):
    print("Received event: " + json.dumps(event))

    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        df = pandas.read_parquet("s3://{0}/{1}".format(bucket,key), engine='auto', columns=None, storage_options=None, use_nullable_dtypes=False, **kwargs)
        print(df.head(1))
        return response['ContentType']
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e    