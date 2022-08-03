import boto3
import json
import time
import os
from datetime import datetime
from random import randint
import requests

my_stream_name = 'test-stream'
api_address = 'https://9rtuubvy0f.execute-api.ap-northeast-2.amazonaws.com/s1/streams/test-stream/record'

def put_to_api(temp, humi, co2, pres, timestamp, devi):
        payload = {
            "result": "success",
            "error_code": err,
            "device_id": devi,
            "coord": {
                "lon": "-8.61",
                "lat": "41.15"
            },
            "server_time": timestamp,
            "temperature": temp,
            "pressure": pres,
            "humidity": humi,
            "co2": co2
        }

        data_set = {
                "Data": payload,
                "PartitionKey": "count",
                "StreamName": "test-stream"
            }
        

        put_response = requests.put(url= api_address,
                                data=json.dumps(data_set),
                                headers={
                                    'Content-type': 'application/json'}
                                # params={'file': filepath}
                                )

        print(put_response)
        return put_response

i = 0

while i < 3:
        err_randint = randint(0,4)
        if err_randint == 0:
            err = 1
        else:
            err = 0
        devi = '39278391'
        temp = randint(13, 35)
        humi = randint(50, 90)
        pres = randint(750, 1500)
        co2  = randint(675, 825)
        timestamp = time.time()

        result = put_to_api(temp, humi, co2, pres ,timestamp ,devi)
        print('response: {}'.format(result))
        time.sleep(5)
        i = i + 1