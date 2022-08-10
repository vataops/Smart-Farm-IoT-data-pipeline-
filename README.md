# **TeamA : 스마트팜 IoT 데이터 파이프라인**
## 요구사항
- 농장주는 실시간 센서 정보를 확인할 수 있어야 합니다.
- IoT 디바이스에는 온도, 습도 및 이산화탄소 정보를 수집/생성하는 애플리케이션이 존재합니다.
- 수집/생성 애플리케이션으로부터 발생한 로그가 데이터 파이프라인을 통해 실시간으로 로그 저장소에 전송되어야 합니다.
- 로그는 조건에 맞게 쿼리하여 사용할 수 있어야 합니다. 보통 시계열 기반의 정보를 조회합니다. (예: 지난 7일간 온도 추이)
- 서비스 간의 연결은 서버리스 형태로 구성해야 합니다.
## 구현사항
> 스마트팜의 온실마다 설치되어 있는 IoT 디바이스에 설치된 온도, 습도 및 이산화탄소 센서로부터 데이터를 수집하고, 이를 실시간으로 데이터 파이프라인을 이용해 **로그 저장소로 전송**합니다.
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
### [6. 아키텍처 실행 가이드](#아키텍처를-어떻게-실행하나요)
- Terraform 의 ```README.md``` 파일 참조
### [7. Resource](#resource)
- Resource 설명

## **Architecture Image**
```아키텍처 이미지```

## **실시간 데이터 수집/저장**
1. 수집/생성 Application으로부터 발생한 로그가 Kinesis Proxy 역할을 하는 [ApiGateway](#amazon-api-gateway) ```kinesis_api_gw```를 통해 **데이터 파이프라인으로 진입**합니다.
2. 진입한 로그는 [Kinesis DataStream](#amazon-kinesis-datastream) 을 통해 **실시간으로 수집**됩니다.
3. Kinesis DataStream 에서 수집한 로그는 S3로 저장되기 전, [Kinesis Data Firehose](#amazon-kinesis-data-firehose) 를 이용하여 **ETL 작업**이 이루어집니다.
    - ```JSON -> parquet```
    - 이때, Kinesis Data Firehose는 [AWS Glue Data Catalog](#aws-glue) 의 ```Database Table```을 참조합니다.
        - ```Database Table```은 **수집된 로그의 데이터 스키마 정보**를 가지고 있습니다.
4. 이후, 로그는 데이터 저장소인 [S3](#aws-s3) 인 ```sensor-log-bucket```에 저장됩니다.

## **Monitoring**
1. AWS Glue DataCatalog의 _Crawler_ 는 ```sensor-log-bucket``` 에 저장된 로그를 불러와 **_Table_ 을 생성**합니다.
2. [Amazon Athena](#amazon-athena) 가 생성된 _Table_ 을 참조하여 **query를 실행**합니다.
3. Monitoring Tool인 Grafana는 Athena와 연결되어 **시각화를 진행**합니다.
    - Grafana는 [**Amazon EC2**](#amazon-ec2) 를 활용하여 구동됩니다.
    - Grafana가 설치된 EC2의 _Endpoint_ 는 **Route53의 레코드**로 등록합니다.
4. 농장주는 **[Route53](#route53) 의 도메인**으로 접속하면 로그를 **모니터링**할 수 있습니다.
## **이상 데이터 처리**
1. 로그 저장소 ```sensor-log-bucket```에 **데이터가 저장되면** [AWS Lambda](#aws-lambda) 가 실행됩니다.
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

## **아키텍처를 어떻게 실행하나요?**
<a href="https://github.com/cs-devops-bootcamp/devops-02-Final-TeamA-scenario1/blob/main/terraform/README.md"><img src="assets/Terraform.png" width="500"/></a>
> 위의 이미지를 클릭하면 Terraform README.md로 이동합니다.

## **Resource**
### [Amazon API Gateway](https://docs.aws.amazon.com/ko_kr/apigateway/latest/developerguide/welcome.html)
- Amazon API Gateway는 규모와 관계없이 REST 및 WebSocket API를 생성, 게시, 유지, 모니터링 및 보호하기 위한 AWS 서비스입니다.
- API Gateway는 다음을 지원하는 서비스입니다.
    - 백엔드 HTTP 엔드포인트, AWS Lambda 함수 또는 기타 AWS 서비스를 노출하기 위한 RESTful 애플리케이션 프로그래밍 인터페이스(API)의 생성, 배포 및 관리합니다.
    - AWS Lambda 함수 또는 기타 AWS 서비스를 노출하기 위한 WebSocket API의 생성, 배포 및 관리합니다.
    - 프런트 엔드 HTTP 및 WebSocket 엔드포인트를 통해 노출된 API 메서드 호출합니다.
### [Amazon Kinesis DataStream](https://docs.aws.amazon.com/ko_kr/streams/latest/dev/introduction.html)
- Kinesis DataStream 을 사용하여 대규모 데이터를 수집/처리할 수 있습니다. Data Stream의 데이터 레코드가 실시간으로 표시됩니다.
- Kinesis DataStream 을 사용하는 일반적인 시나리오
    - 가속화된 로그 및 데이터 피드 인테이크 및 처리
        - 생산자를 통해 스트림으로 직접 데이터를 푸시할 수 있습니다.
    - 실시간 측정치 및 보고
    - 실시간 데이터 분석
    - 복잡한 스트림 처리
        - Kinesis Data Streams 애플리케이션 및 데이터 스트림의 DAG (방향 비순환 그래프) 를 생성할 수 있습니다.
- Kinesis Data Streams High-Level Architecture
    <img src="https://docs.aws.amazon.com/streams/latest/dev/images/architecture.png"/>
### [Amazon Kinesis Data Firehose](https://docs.aws.amazon.com/ko_kr/firehose/latest/dev/what-is-this-service.html)
- Amazon Kinesis Data Firehose 는 실시간 전송을 위한 완전관리형 서비스입니다.
- Kinesis 스트리밍 데이터 플랫폼의 일부이며 Kinesis Data Firehose Firehose를 사용하면 애플리케이션을 쓰거나 리소스를 관리할 필요가 없습니다.
- 데이터를 보내도록 데이터 생산자를 구성하면 지정한 대상으로 데이터를 자동으로 전송합니다. 전송 전에 Kinesis Data Firehose Firehose를 구성하여 데이터를 변환할 수도 있습니다.
### [AWS Glue](https://docs.aws.amazon.com/ko_kr/glue/latest/dg/what-is-glue.html)
- AWS Glue는 완전 관리형 추출, 변환 및 로드(ETL) 서비스로, 효율적인 비용으로 간단하게 여러 데이터 스토어 및 데이터 스트림 간에 원하는 데이터를 분류, 정리, 보강, 이동합니다.
- AWS Glue는 AWS Glue Data Catalog로 알려진 중앙 메타데이터 리포지토리, 자동으로 Python 및 Scala 코드를 생성하는 ETL 엔진, 그리고 종속성 확인, 작업 모니터링 및 재시도를 관리하는 유연한 스케줄러로 구성됩니다.
- AWS Glue는 서버리스이므로 설정하거나 관리할 인프라가 없습니다.
- 언제 AWS Glue를 사용해야 합니까?
    - AWS Glue를 사용하여 데이터 웨어하우스 또는 데이터 레이크의 스토리지에 데이터를 구성, 정리, 검증 및 포맷할 수 있습니다.
    - Amazon S3 데이터 레이크에 대해 서버리스 쿼리를 실행할 때 AWS Glue를 사용할 수 있습니다.
    - AWS Glue 로 이벤트 중심 ETL 파이프라인을 생성할 수 있습니다.
    - AWS Glue를 사용하여 데이터 자산을 이해합니다.
- [AWS Glue Data Catalog](https://docs.aws.amazon.com/ko_kr/prescriptive-guidance/latest/serverless-etl-aws-glue/aws-glue-data-catalog.html)
    - AWS Glue Data Catalog는 다음과 같은 구성 요소로 이루어집니다.
        - Databases and tables
        - Crawlers and classifiers
        - Connections
        - AWS Glue Schema Registry
    - [Databases and Tables](https://docs.aws.amazon.com/ko_kr/glue/latest/dg/tables-described.html)
        - 테이블은 하나의 데이터베이스에만 있을 수 있습니다.
        - Data Catalog 데이터베이스 및 해당 테이블의 샘플 뷰
            <img src="https://docs.aws.amazon.com/ko_kr/prescriptive-guidance/latest/serverless-etl-aws-glue/images/aws-glue-data-catalog-example.png">
    - Crawlers and classifiers
        - [Crawler](https://docs.aws.amazon.com/ko_kr/glue/latest/dg/add-crawler.html) 는 데이터 카탈로그 테이블을 만들고 업데이트할 수 있습니다. 파일 기반 및 테이블 기반 데이터 스토어를 크롤할 수 있습니다.
        - [Crawler classifier](https://docs.aws.amazon.com/ko_kr/glue/latest/dg/add-classifier.html) 는 데이터 포맷을 인식하고 스키마를 생성합니다.
### [Amazon Athena](https://docs.aws.amazon.com/ko_kr/athena/latest/ug/what-is.html)
- Amazon Athena는 표준 SQL을 사용하여 Amazon S3(Amazon Simple Storage Service)에 있는 데이터를 직접 간편하게 분석할 수 있는 대화형 쿼리 서비스입니다.
- Athena는 서버리스 서비스이므로 설정하거나 관리할 인프라가 없으며 실행한 쿼리에 대해서만 비용을 지불하면 됩니다. Athena는 자동으로 확장되어 쿼리를 병렬로 실행하여 대규모 데이터 집합과 복잡한 쿼리에서도 빠르게 결과를 얻을 수 있습니다.
### [Amazon EC2](https://docs.aws.amazon.com/ko_kr/AWSEC2/latest/UserGuide/concepts.html)
- Amazon Elastic Compute Cloud(Amazon EC2)는 Amazon Web Services(AWS) 클라우드에서 확장 가능한 컴퓨팅 용량을 제공합니다.
- 하드웨어에 선투자할 필요가 없어 더 빠르게 애플리케이션을 개발하고 배포할 수 있습니다.
- Amazon EC2를 사용하여 원하는 수의 가상 서버를 구축하고 보안 및 네트워킹을 구성하며 스토리지를 관리할 수 있습니다.
- Amazon EC2에서는 확장 또는 축소를 통해 요구 사항 변경 또는 사용량 스파이크를 처리할 수 있으므로 트래픽을 예측할 필요성이 줄어듭니다.
### [Amazon Route53](https://docs.aws.amazon.com/ko_kr/Route53/latest/DeveloperGuide/Welcome.html)
- 가용성과 확장성이 뛰어난 DNS(Domain Name System) 웹 서비스입니다.
- Route 53을 사용하여 세 가지 주요 기능,
    - 즉, 도메인 등록, DNS 라우팅, 상태 확인을 조합하여 실행할 수 있습니다.
### [Amazon S3](https://docs.aws.amazon.com/ko_kr/AmazonS3/latest/userguide/Welcome.html)
- Amazon Simple Storage Service(Amazon S3)는 높은 확장성, 데이터 가용성, 보안 및 성능을 제공하는 객체 스토리지 서비스입니다.
- Amazon S3는 특정 비즈니스, 조직 및 규정 준수 요구 사항에 맞게 데이터에 대한 액세스를 최적화, 구조화 및 구성할 수 있는 관리 기능을 제공합니다.
- 기능
    - 스토리지 클래스
        - 여러 사용 사례에 맞춰 설계된 다양한 스토리지 클래스를 제공합니다.
    - 스토리지 관리
    - 액세스 관리
        - 버킷 및 객체에 대한 액세스 감사 및 관리 기능을 제공합니다.
        - 기본적으로 S3 버킷 및 객체는 프라이빗입니다.
    - 데이터 처리
    - 스토리지 로깅 및 모니터링
        - 리소스가 사용되는 방식을 모니터링하고 제어하는 데 사용할 수 있는 로깅 및 모니터링 도구를 제공합니다.
    - 분석 및 인사이트
        - 스토리지 사용량을 파악할 수 있는 기능을 제공하며, 이를 통해 규모에 따라 스토리지를 더 잘 이해하고 분석하며 최적화할 수 있습니다.
    - 강력한 일관성
### [AWS Lambda](https://docs.aws.amazon.com/ko_kr/lambda/latest/dg/welcome.html)
- Lambda는 서버를 프로비저닝하거나 관리하지 않고도 코드를 실행할 수 있게 해주는 컴퓨팅 서비스입니다.
-  Lambda는 필요 시에만 함수를 실행하며, 일일 몇 개의 요청에서 초당 수천 개의 요청까지 자동으로 확장이 가능합니다. 사용한 컴퓨팅 시간만큼만 비용을 지불하고, 코드가 실행되지 않을 때는 요금이 부과되지 않습니다.
- Lambda API를 사용하여 Lambda 함수를 호출하거나, Lambda가 다른 AWS 서비스의 이벤트에 응답하여 함수를 실행할 수 있습니다.
 - Lambda를 사용하여 다음을 수행할 수 있습니다.
    - Amazon Simple Storage Service(Amazon S3) 및 Amazon DynamoDB와 같은 AWS 서비스를 위한 데이터 처리 트리거를 빌드할 수 있습니다.
    - Amazon Kinesis에 저장된 스트리밍 데이터를 처리할 수 있습니다.
    - AWS 규모, 성능 및 보안으로 작동하는 고유한 백엔드를 만듭니다.