import boto3
import json
import time
from datetime import datetime
from dotenv import load_dotenv
from random import randint
import os
load_dotenv()

my_stream_name = 'kinesis-data-stream'

client = boto3.client('kinesis', region_name='ap-northeast-2', aws_access_key_id=os.environ.get('AWS_ACCESS'), aws_secret_access_key=os.environ.get('AWS_PRIVATE'))

def put_to_stream(temp, humi, co2, pres ,timestamp ,devi, flag):
    result = "success"
    error_code = 0

    if flag ==1:
        result = "fail"
        error_code = 1

    payload = {
        "result": result,
        "error_code": error_code,
        "device_id": devi,
           "coord": {
                "lon": "-8.61",
                "lat": "41.15"
              },
        "server_time": timestamp,
        "temperature": temp,
        "pressure": pres,
        "humidity": humi,
        "co2": co2,
    }

    put_response = client.put_record(
                    StreamName=my_stream_name,
                    Data=json.dumps(payload),
                    PartitionKey=devi)
    return put_response

while True:
    devi = '39278391'
    temp = randint(0, 40)
    humi = randint(0, 40)
    pres = randint(0, 40)
    co2  = randint(0, 40)

    flag = randint(1,10)
    timestamp = time.strftime('%c', time.localtime(time.time()))

    result = put_to_stream(temp, humi, co2, pres ,timestamp ,devi, flag)

    time.sleep(10)
    print('response: {}'.format(result))
