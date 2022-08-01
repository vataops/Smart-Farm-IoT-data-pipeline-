import json
import urllib.parse
import boto3
import pandas
import pyarrow.parquet as pq
import io

def hello(event, context):
    # print("Received event: " + json.dumps(event))

    buffer = io.BytesIO() # buffer 저장공간 확보
    s3 = boto3.resource('s3')
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    # print('bucketbucket: ' + bucket)
    # print('keykey: ' + key)
    try:
        # if문 추가 : 비정상적인 데이터 정제
        # 비정상적인 데이터 검출 시, 다른 파일로 이어지게..?
        s3_object = s3.Object(bucket, key)
        s3_object.download_fileobj(buffer) # s3에서 받아온 데이터를 buffer에 파일 형태로 저장
        table = pq.read_table(buffer) # buffer 데이터를 테이블 형식으로 불러오기
        df = table.to_pandas() # pandas dateframe 형식으로 buffer 데이터 테이블 저장
        print(df.head(1))
        return "Hello"
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e    