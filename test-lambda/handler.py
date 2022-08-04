import json
import time
from datetime import datetime
from random import randint
import requests
import os

my_stream_name = 'tf-test-stream'
api_address = os.getenv('API_ENDPOINT')

def put_to_api(temp, humi, co2, pres, timestamp, devi, err):
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
            "StreamName": my_stream_name
           }

    put_response = requests.put(url=api_address,
                                    data=json.dumps(data_set),
                                    headers={
                                        'Content-type': 'application/json'}
                                    # params={'file': filepath}
                                    )

    print(put_response)
    return put_response

def hello(event, context):
    print(event['body'])

    ev = json.loads(event['body'])

    count = ev["count"]
    inter = ev["interval"]

    print(count)
    print(inter)

    i = 0

    device_num = 2;

    while i < count:
        err_randint_1 = randint(0, 4)
        err_randint_2 = randint(0, 5)

        if err_randint_1 == 0:
            err_1 = 1
        else:
            err_1 = 0
        if err_randint_2 == 0:
            err_2 = 1
        else:
            err_2 = 0
        
        devi_1 = '39278391'
        devi_2 = '51539982'

        temp = randint(13, 35)
        humi = randint(50, 90)
        pres = randint(750, 1500)
        co2 = randint(675, 825)
        timestamp = time.time()

        result_1 = put_to_api(temp, humi, co2, pres, timestamp , devi_1, err_1)
        print('response: {}'.format(result_1))

        result_2 = put_to_api(temp, humi, co2, pres, timestamp, devi_2, err_2)
        print('response: {}'.format(result_2))
        time.sleep(inter)


        i = i + 1

    message = {'테스트 device 수': device_num, '총 실행시간': count*inter}

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(message)
    }
