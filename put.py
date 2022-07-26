import boto3
import time
import json

client = boto3.client('kinesis', region_name='ap-northeast-2', aws_access_key_id='', aws_secret_access_key='')

def put_records(records):

    kinesis_records = []

    for r in records:
        kinesis_records.append(
            {
                    'Data': json.dumps(r).encode('utf-8'),
                    # 'ExplicitHashKey': 'string',
                    'PartitionKey': 'string_for_partition'
            }
        )

    response = client.put_records(
        Records=kinesis_records,
        StreamName='test-final'
    )

    return response


def main():
    while True:
        print('start to send')
        data = [
            {
                'time': time.time()
            },
            {
                'time': time.time()+10
            }
        ]
        response = put_records(data)
        print('response: {}'.format(response))

        time.sleep(10)


if __name__ == "__main__":
    # execute only if run as a script
    main()
