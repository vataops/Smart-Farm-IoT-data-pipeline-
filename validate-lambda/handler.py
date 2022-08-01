import json
import urllib.parse
import boto3
import pandas
import pyarrow.parquet as pq
import io

def hello(event, context):
    # print("Received event: " + json.dumps(event))

    buffer = io.BytesIO()
    s3 = boto3.resource('s3')
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    # print('bucketbucket: ' + bucket)
    # print('keykey: ' + key)
    try:
        # if문 추가 : 비정상적인 데이터 정제
        # 비정상적인 데이터 검출 시, 다른 파일로 이어지게..?
        s3_object = s3.Object(bucket, key)
        s3_object.download_fileobj(buffer)
        table = pq.read_table(buffer)
        df = table.to_pandas()
        print(df.head(1))
        return "Hello"
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e    