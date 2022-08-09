import json
import urllib.parse
import boto3
import pandas as pd
import pyarrow.parquet as pq
import io
import time
import os
import datetime

from time import localtime
from time import strftime
from base64 import b64decode
from urllib.request import Request, urlopen


def hello(event, context):
    buffer = io.BytesIO() # buffer 저장공간 확보
    s3 = boto3.resource('s3')
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    korea_time = datetime.datetime.now() + datetime.timedelta(hours = 9)
    dest_s3_name = os.environ.get('DEST_S3_NAME')
    file_name = korea_time.strftime('%Y-%m-%d-%I:%M:%S%p.parquet')
    HOOK_URL = os.environ.get('HOOK_URL')

    discord_message = []
    err_discord_message = []
    dev_id_df = []
    message_arr = []
    err_message_arr= []
    
    dest_s3 = s3.Bucket(dest_s3_name)
    s3_object = s3.Object(bucket, key)
    s3_object.download_fileobj(buffer) # s3에서 받아온 데이터를 buffer에 파일 형태로 저장
    table = pq.read_table(buffer) # buffer 데이터를 테이블 형식으로 불러오기
    df = table.to_pandas() # pandas dateframe 형식으로 buffer 데이터 테이블 저장

    # df의 데이터를 조건에 맞게 쿼리
    err = df[(df.error_code == 1)]
    temp = df[(df.temperature <= 18) | (df.temperature >= 27)]
    hum = df[(df.humidity <= 60) | (df.humidity >= 80)]
    co2 = df[(df.co2 <= 650) | (df.co2 >= 750)]

    # 쿼리한 데이터를 모으기
    filtered_df = pd.concat([err, temp, hum, co2]).drop_duplicates(subset=["server_time", "device_id"], ignore_index=True)

    # 하나라도 있으면 discord webhook 전송
    if len(filtered_df) != 0 :
        unique_dev_ids = filtered_df.device_id.unique() # 고유한 device_id 추출

        # 각 데이터마다 추출해서 배열화
        err_arr = filtered_df.error_code.to_numpy()
        time_arr = filtered_df.server_time.to_numpy()
        device_id_arr = filtered_df.device_id.to_numpy()
        temp_arr = filtered_df.temperature.to_numpy()
        pres_arr = filtered_df.pressure.to_numpy()
        hum_arr = filtered_df.humidity.to_numpy()
        co2_arr = filtered_df.co2.to_numpy()

        # device_id로 이상 데이터 나누기
        for dev_id in unique_dev_ids:
            dev_id_df = filtered_df[filtered_df.device_id == dev_id]

        # 두가지 데이터를 따로 전송
        # error_code == "1"인 데이터 Webhook 전송 (행별로 찾아서 전송)
        for i in range(len(dev_id_df)) :
            if err_arr[i] == "1":
                message = '{} \n device {}번 센서가 아파요'.format(time_arr[i], device_id_arr[i])
                err_message_arr.append(message) # message format을 반복적으로 arr 형식에 추가
                err_result = "\n --- \n".join(err_message_arr) # err_message_arr를 기준에 따라 나눠, String 형식으로 묶음
                err_discord_message = {
                    'username': 'Sensor_Manager',
                    'content': err_result
                }
        
        # error_code != "1"인 데이터 Webhook 전송
        for i in range(len(dev_id_df)) :
            if err_arr[i] == "0":
                message = '{} \n device {}에서 이상 데이터가 감지됨 \n temperature : {}\u00B0 \n pressure : {}hPa \n humidity : {}% \n co2 : {}ppm'.format(time_arr[i], device_id_arr[i], temp_arr[i],pres_arr[i], hum_arr[i], co2_arr[i])
                message_arr.append(message)
                result = "\n --- \n".join(message_arr)
                discord_message = {
                    'username': 'Sensor_Manager',
                    'content': result
                }

        # HTTP 요청 format (두가지 데이터 구별)
        payload = json.dumps(discord_message).encode('utf-8')
        err_payload = json.dumps(err_discord_message).encode('utf-8')
        headers = {
            'Content-Type': 'application/json; charset=utf-8',
            'Content-Length': len(payload),
            'Host': 'discord.com',
            'user-agent': 'Mozilla/5.0'
        }
        err_headers = {
            'Content-Type': 'application/json; charset=utf-8',
            'Content-Length': len(err_payload),
            'Host': 'discord.com',
            'user-agent': 'Mozilla/5.0'
        }

        # parquet 파일로 변환
        os.chdir('/tmp')
        os.makedirs('dest_s3', exist_ok= True)
        os.chdir('dest_s3')
        result = filtered_df.to_parquet(file_name)

    try:
        # 이상 데이터가 있다면 Webhook 전송 (두가지 데이터 구별)
        if len(filtered_df) != 0:
            err_req = Request(HOOK_URL, err_payload, err_headers)
            err_response = urlopen(err_req)
            err_response.read()

            req = Request(HOOK_URL, payload, headers)
            response = urlopen(req)
            response.read()
            print('Webhook 전송 성공')

            # dest_s3에 파일 저장
            # file = io.BytesIO(bytes(result), encoding = 'utf-8')
            # bucket_object = dest_s3.Object(file_name)
            dest_s3.upload_file('/tmp/dest_s3/{}'.format(file_name), file_name)
            print('S3에 저장 성공')

            return 'Process Succeeded'

    except Exception as e:
        print(e)
        print('이상 데이터 없음')
        raise e   