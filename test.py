import json
import time
from datetime import datetime
from random import randint
import requests
import os

my_stream_name = 'tf-test-stream'
api_address = "https://pxfe7v0d79.execute-api.ap-northeast-2.amazonaws.com/s1/streams/tf-test-stream/record"
def put_to_api(temp, humi, co2, pres, timestamp, devi, err, lon, lat):
    payload = {
            "result": "success",
            "error_code": err,
            "device_id": devi,
            "coord": {
                "lon": lon,
                "lat": lat
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
                                        'Content-type': 'application/x-amz-json-1.1'}
                                    # params={'file': filepath}
                                    )

    print(put_response)
    return put_response


count = 1000
inter = 10

# print(count)
# print(inter)

i = 0

device_num = 2

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
    
    #device_id, lon, lat
    devi_1 = ['39278391', '34', '-118.24']
    devi_2 = ['51539982', '37.3', '-122']

    temp1 = randint(13, 35)
    temp2 = randint(13, 35)
    humi1 = randint(50, 90)
    humi2 = randint(50, 90)
    pres1 = randint(750, 1500)
    pres2 = randint(750, 1500)
    co21 = randint(675, 825)
    co22 = randint(675, 825)
    timestamp = time.time()

    result_1 = put_to_api(temp1, humi1, co21, pres1, timestamp, devi_1[0], err_1, devi_1[2], devi_1[1])
    print('response: {}'.format(result_1))

    result_2 = put_to_api(temp2, humi2, co22, pres2, timestamp, devi_2[0], err_2, devi_2[2], devi_2[1])
    print('response: {}'.format(result_2))
    time.sleep(inter)


    i = i + 1
