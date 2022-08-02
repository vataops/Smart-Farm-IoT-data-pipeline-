import json
import urllib.parse
import boto3
import pandas as pd
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

        # df의 데이터를 조건에 맞게 쿼리
        err = df[(df.error_code == 1)]
        temp = df[(df.temperature <= 17) | (df.temperature >= 28)]
        hum = df[(df.humidity <= 59) | (df.humidity >= 81)]
        co2 = df[(df.co2 <= 650) | (df.co2 >= 750)]

        filtered_df = pd.concat([err, temp, hum, co2], ignore_index = True)
        result = filtered_df.to_parquet()
        return filtered_df
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e    