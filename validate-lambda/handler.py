import json
import urllib.parse
import boto3
import pandas as pd
import pyarrow.parquet as pq
import io
import time
from time import localtime
from time import strftime
import os
import datetime

def hello(event, context):
    # print("Received event: " + json.dumps(event))

    buffer = io.BytesIO() # buffer 저장공간 확보
    s3 = boto3.resource('s3')
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    korea_time = datetime.datetime.now() + datetime.timedelta(hours = 9)
    dest_s3_name = os.environ.get('DEST_S3_NAME')
    file_name = korea_time.strftime('%Y-%m-%d-%I:%M:%S%p.parquet')


    # print('bucketbucket: ' + bucket)
    # print('keykey: ' + key)
    try:
        s3_object = s3.Object(bucket, key)
        s3_object.download_fileobj(buffer) # s3에서 받아온 데이터를 buffer에 파일 형태로 저장
        table = pq.read_table(buffer) # buffer 데이터를 테이블 형식으로 불러오기
        df = table.to_pandas() # pandas dateframe 형식으로 buffer 데이터 테이블 저장

        # df의 데이터를 조건에 맞게 쿼리
        err = df[(df.error_code == 1)]
        temp = df[(df.temperature <= 17) | (df.temperature >= 28)]
        hum = df[(df.humidity <= 59) | (df.humidity >= 81)]
        co2 = df[(df.co2 <= 650) | (df.co2 >= 750)]

        # 쿼리한 데이터를 모으고, parquet 파일로 변환
        filtered_df = pd.concat([err, temp, hum, co2]).drop_duplicates(subset=["server_time"], ignore_index=True)
        os.chdir('/tmp')
        os.makedirs('dest_s3', exist_ok= True)
        os.chdir('dest_s3')
        result = filtered_df.to_parquet(file_name)
        print('변환 성공')

        # dest_s3에 파일 저장
        # file = io.BytesIO(bytes(result), encoding = 'utf-8')
        dest_s3 = s3.Bucket(dest_s3_name)
        # bucket_object = dest_s3.Object(file_name)
        dest_s3.upload_file('/tmp/dest_s3/{}'.format(file_name), file_name)
        print('성공')

        return 'success'
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e    