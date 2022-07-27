import boto3
import json
import time
from datetime import datetime
from random import randint

my_stream_name = 'test-final'

client = boto3.client('kinesis', region_name='ap-northeast-2', aws_access_key_id='', aws_secret_access_key='')

def put_to_stream(temp, humi, co2, pres ,timestamp ,devi):
    payload = {
        "result": "success",
        "error_code": "0",
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
    timestamp = time.strftime('%c', time.localtime(time.time()))

    result = put_to_stream(temp, humi, co2, pres ,timestamp ,devi)

    time.sleep(10)
    print('response: {}'.format(result))