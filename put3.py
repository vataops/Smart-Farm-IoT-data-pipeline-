import boto3
import json
import time
import os
from datetime import datetime
from random import randint
import requests

my_stream_name = 'test-stream'
api_address = 'https://9rtuubvy0f.execute-api.ap-northeast-2.amazonaws.com/s1/streams/test-stream/record'


data_set = {
    "Data": "{ 'count': 3, 'interval': 10 }",
    "PartitionKey": "count",
    "StreamName": "test-stream"
}

put_response = requests.put(url=api_address,
                            data=json.dumps(data_set),
                            headers={'Content-type': 'application/json'}
                                # params={'file': filepath}
                                )
print(put_response)
