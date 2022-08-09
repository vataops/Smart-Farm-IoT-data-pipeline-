# **TeamA : 스마트팜 IoT 데이터 파이프라인**
## 요구사항
- 농장주는 실시간 센서 정보를 확인할 수 있어야 합니다.
- IoT 디바이스에는 온도, 습도 및 이산화탄소 정보를 수집/생성하는 애플리케이션이 존재합니다.
- 수집/생성 애플리케이션으로부터 발생한 로그가 데이터 파이프라인을 통해 실시간으로 로그 저장소에 전송되어야 합니다.
- 로그는 조건에 맞게 쿼리하여 사용할 수 있어야 합니다. 보통 시계열 기반의 정보를 조회합니다. (예: 지난 7일간 온도 추이)
- 서비스 간의 연결은 서버리스 형태로 구성해야 합니다.
## 구현사항
> 스마트팜 기업 팜스테이츠는 스마트팜의 온실마다 설치되어 있는 IoT 디바이스에 설치된 온도, 습도 및 이산화탄소 센서로부터 **데이터를 수집**하고, 이를 실시간으로 데이터 파이프라인을 이용해 **로그 저장소로 전송**합니다. 
>
> 농장주는 이러한 센서 정보를 **실시간으로 모니터링**할 수 있고, 로그 저장소에 저장된 정보를 바탕으로 **시계열 기반의 정보** 또한 확인 가능합니다.
>
> 또한 **이상 데이터**를 따로 모아 확인할 수 있으며, 이상 데이터 발생 시, **Discord로 알림**을 보냅니다.
>
> 수집/생성 Application을 대신해, Architecture **테스트를 위한 로그 데이터**를 전송할 수 있습니다.

## **목차**
### 1. Architecture Image
### [2. 실시간 데이터 수집/저장](#실시간-데이터-수집저장)
- 데이터 파이프라인 진입
### [3. Monitoring](#monitoring)
- 데이터 시각화, Monitoring
### [4. 이상 데이터 처리](#이상-데이터-처리)
- Discord 알림 전송
### [5. Architecture 테스트](#architecture-test)
- 가상의 로그 데이터 전송
### [6. Resource](#resource)
- Resource 설명

## **Architecture Image**
```아키텍처 이미지```

## **실시간 데이터 수집/저장**
1. 수집/생성 Application으로부터 발생한 로그가 ApiGateway ```kinesis_api_gw```를 통해 **데이터 파이프라인으로 진입**합니다.
2. 진입한 로그는 Kinesis DataStream을 통해 **실시간으로 수집**됩니다.
3. Kinesis DataStream에서 수집한 로그는 S3로 저장되기 전, Kinesis Firehose를 이용하여 **ETL 작업**이 이루어집니다.
    - ```JSON -> parquet```
    - 이때, Kinesis Firehose는 AWS Glue DataCatalog의 ```Database Table```을 참조합니다.
        - ```Database Table```은 **수집된 로그의 데이터 스키마 정보**를 가지고 있습니다.
4. 이후, 로그는 데이터 저장소인 S3인 ```sensor-log-bucket```에 저장됩니다.

## **Monitoring**
1. AWS Glue DataCatalog의 _Crawler_ 는 ```sensor-log-bucket``` 에 저장된 로그를 불러와 **_Table_ 을 생성**합니다.
2. AWS Athena가 생성된 _Table_ 을 참조하여 **query를 실행**합니다.
3. Monitoring Tool인 Grafana는 Athena와 연결되어 **시각화를 진행**합니다.
    - Grafana는 **AWS EC2**를 활용하여 구동됩니다.
    - Grafana가 설치된 EC2의 _Endpoint_ 는 **Route53의 레코드**로 등록합니다.
4. 농장주는 **Route53의 도메인**으로 접속하면 로그를 **모니터링**할 수 있습니다.
## **이상 데이터 처리**
1. 로그 저장소 ```sensor-log-bucket```에 **데이터가 저장되면** AWS Lambda가 실행됩니다.
    - 이때, AWS Lambda는 이상 데이터가 발생했는 지, 확인합니다.
        - 이상 데이터의 기준

            | 기준 | 예시 코드 |
            | --- | --- |
            |센서에 이상이 있는 가? | ```error_code = "1"```|
            |비정상적인 수치가 보이는 가? | ```temperature = "400"```|
2. _**이상 데이터가 발생했다면,**_
    - AWS Lambda의 로직으로 인해 **Discord Webhook을 통해 알림**을 보냅니다.
    - 그 후, 이상 데이터만 선별하여 S3인 ```spike-log-bucket```에 **따로 저장**합니다.

## **Architecture Test**
### 가상의 로그 데이터 전송
1. AWS Lambda인 ```pseudo_sensor_log_lambda```의 API Gateway인 ```pseudo_api_gw```의 _Endpoint_ 에 요청 _body_ 를 담아, **POST 요청**을 보냅니다.
2. ```pseudo_api_gw```에 의해 실행된 ```pseudo_sensor_log_lambda```는 요청한 _body_ 에 따라 로직을 실행,
    - ```kinesis_api_gw```의 **_Endpoint_ 로 요청**을 보냅니다.
### _**HTTP Request 예시**_
```
POST / 
Content-Type : application/json
```
```
{
    "count" : 12,
    "interval" : 10
}
```
> **_Endpoint_ : ```pseudo_api_gw```의 _Endpoint_**
> | Name     | Type | Description   |
> |----------|:----:|---------------|
> | count    | int  | 전송할 데이터의 갯수 | 
> | interval | int  | 전송할 데이터의 간격 (초 단위)| 

### **Resource**
- AWS API Gateway
- AWS Kinesis DataStream
- AWS Kinesis Firehose
- AWS Glue DataCatalog
    - Table
    - Crawler
- AWS Athena
- AWS EC2
- Route53
- AWS S3
- AWS Lambda