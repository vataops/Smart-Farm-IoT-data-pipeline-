# pseudo-sensor-log-lambda

## Description
![image](https://user-images.githubusercontent.com/89952061/184065575-51b159d2-bc3b-45a8-abc0-9d6b6ebec9c2.png)

- serverless를 활용하여 테스팅 전용으로 사용될 Lambda, API Gateway를 생성합니다.
- API Gateway의 Endpoint에 요청 수(Count), 요청 간격(Interval)을 전달하여 손쉽게 테스팅이 가능합니다.
- pseudo-sensor-log-lambda는 Kinesis Data Stream의 API Endpoint에 데이터를 전송합니다.

> serverless pattern : https://serverlessland.com/patterns/apigw-canary-deployment-cdk

## Files
### `serverless.yml`
- serverless framwork를 통해 AWS의 여러 Resource를 설정하고 생성하기 위해서 사용되는 yml 파일입니다.
```
service: test-lambda
frameworkVersion: '3'

provider:
  name: aws
  runtime: python3.8
  region: ap-northeast-2

functions:
  hello:
    handler: handler.hello
    timeout: 60
    events:
      - httpApi:
          path: /
          method: '*'
```
- provider 이름과 런타임, 리전 그리고 Lambda의 handler와 메소드를 설정합니다. 
- trigger로 사용될 Api gateway를 생성합니다.

### `handler.py`
- trigger에 의해 실행될 파이썬 스크립트 파일입니다.
```
...

def hello(event, context):
    print(event['body'])

    ev = json.loads(event['body'])

    count = ev["count"]
    inter = ev["interval"]

    print(count)
    print(inter)

    i = 0

    device_num = 2
...
```
- Lambda 실행 시 handler의 hello 메소드부터 호출합니다.

### `test-handler.py`
- terraform으로 아키텍처 구현 시, pseudo_sensor_log_lambda의 handler로 사용될 파이썬 스크립트 파일입니다.

## Usage

### serverless 설치
- install serverless

```npm install -g serverless```
- pseudo-sensor-log-lambda 디렉토리 이동

```cd pseudo-sensor-log-lambda```
- serverless 디플로이

```sls deploy```

### 테스트 방법
- API_ENDPOINT : Kinesis Data Stream의 API Endpoint
```
...
// handler.py
api_address = os.getenv('API_ENDPOINT')
...
```
- Method : POST
- API Endpoint : 생성된 pseudo-sensor-log-lambda의 API Endpoint
- Content-Type : application/json
- Parameter : count(요청 횟수), interval(요청 간격)
- body : 
```
{
    "count": 10,
    "interval": 10
}
```
