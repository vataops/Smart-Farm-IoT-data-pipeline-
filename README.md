# **TeamA : 스마트팜 IoT 데이터 파이프라인**
> 스마트팜 기업 팜스테이츠는 스마트팜의 온실마다 설치되어 있는 IoT 디바이스에 설치된 온도, 습도 및 이산화탄소 센서로부터 **데이터를 수집**하고, 이를 실시간으로 데이터 파이프라인을 이용해 **로그 저장소로 전송**합니다. 
>
> 농장주는 이러한 센서 정보를 **실시간으로 모니터링**할 수 있고, 로그 저장소에 저장된 정보를 바탕으로 **시계열 기반의 정보** 또한 확인 가능합니다.
>
> 또한 **이상 데이터**를 따로 모아 확인할 수 있으며, 이상 데이터 발생 시, **Discord로 알림**을 보냅니다.
## 요구사항
---
- 농장주는 실시간 센서 정보를 확인할 수 있어야 합니다.
- IoT 디바이스에는 온도, 습도 및 이산화탄소 정보를 수집/생성하는 애플리케이션이 존재합니다.
- 수집/생성 애플리케이션으로부터 발생한 로그가 데이터 파이프라인을 통해 실시간으로 로그 저장소에 전송되어야 합니다.
- 로그는 조건에 맞게 쿼리하여 사용할 수 있어야 합니다. 보통 시계열 기반의 정보를 조회합니다. (예: 지난 7일간 온도 추이)
- 서비스 간의 연결은 서버리스 형태로 구성해야 합니다.

```아키텍처 이미지```

```목차```
## **실시간 데이터 수집/저장**
---
- 수집/생성 Application으로부터 발생한 로그가 ApiGateway를 통해 데이터 파이프라인으로 진입합니다.
- 진입한 로그는 Kinesis DataStream을 통해 실시간으로 수집됩니다.
- Kinesis DataStream에서 수집한 로그는 S3로 저장되기 전, Kinesis Firehose를 이용하여 ETL 작업이 이루어집니다.
    - ```JSON -> parquet```
    - 이때, Kinesis Firehose는 AWS Glue DataCatalog의 ```Database Table```을 참조합니다.
        - ```Database Table```은 수집된 로그의 데이터 스키마 정보를 가지고 있습니다.
- 이후, 로그는 데이터 저장소인 S3인 ```farm_sensor_bucket```에 저장됩니다.
## **데이터 시각화**
---
- AWS Glue DataCatalog의 Crawler는 ```farm_sensor_bucket``` 에 저장된 로그를 불러와 Table을 생성합니다.
- AWS Athena가 생성된 Table을 참조하여 query를 실행합니다.
- 시각화 tool인 Grafana는 Athena와 연결되어 시각화를 진행합니다.
    - Grafana는 AWS EC2를 활용하여 구동됩니다.
    - Grafana가 설치된 EC2의 Endpoint는 Route53의 레코드로 등록합니다.
- 농장주는 Route53의 도메인으로 접속하면 시각화된 로그를 볼 수 있습니다.
## **이상 데이터 처리**
---
- 

## **STEP 1**
---
### 환경변수 설정
- ```test_lambda``` 의 environment variable
    ```
    API_ENDPOINT = YourApiGatewayEndpointUrl
    ```
- ```validate_lambda``` 의 environment variable
    ```
    HOOK_URL = YourDiscordWebhookUrl
    DEST_S3_NAME = YourSpikeLogBucketName
    ```
## **STEP 2**
---
