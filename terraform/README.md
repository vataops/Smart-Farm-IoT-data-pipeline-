# Terraform을 활용한 아키텍쳐 IaC화 (수정 중)

## 생성되는 리소스 이름 수정 필요!

<a href="https://www.terraform.io/"><img src="../assets/Terraform.png" alt="centered image" width="500"/></a>

## 주요 목표
- Terraform를 사용해서 스마트팜 IoT 센서 데이터 서비스 구축
- 리소스를 일일이 AWS Console 상에서 만들어야 하는 번거러움을 줄여주기 위한 Reusability 확보

---

## Terraform 파일 명세

#### `main.tf`
- AWS 리소스를 사용하기 위한 provider에 관한 정보를 담고 있는 .tf 파일입니다.

```terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16.0"
    }
  }
  required_version = ">= 1.1.0"
}

```
#### `pseudo-api-service.tf`

<div style="text-align: center;"><img src="../assets/final-architecture-part-1.png" alt="isolated" width="350"/></div>

해당 .tf 파일은 다음과 같은 리소스들을 생성합니다.
- 실시간 센서 데이터를 모방하는 `pseudo-sensor-log-lambda` 함수
- `pseudo-sensor-log-lamdba` 함수를 트리거 하기 위한 API Gateway

#### `kinesis-service.tf`

<div style="text-align: center;"><img src="../assets/final-architecture-part-2.png" alt="isolated" width="600"/></div>

AWS에서 제공하는 매니지드 데이터 스트리밍 서비스인 Amazon Kinesis를 활용하여 파이프라인 구축에 필요한 리소스들을 생성하는 .tf 파일입니다.
- 데이터 스트리밍을 가능하게 해주는 Kinesis Data Stream
- Kinesis Data Stream을 통해 전달되는 데이터에 대한 ETL 작업을 수행하는 Kinesis Firehose Delivery Stream
- ETL 작업이 완료된 데이터를 보관하는 S3 버킷


#### `validate-log-service.tf`
<div style="text-align: center;"><img src="../assets/final-architecture-part-3.png" alt="isolated" width="280"/></div>

정제되어 S3 버킷에 저장된 센서로그에 대한 무결성 검증을 진행하는 서비스를 구축하는 .tf 파일입니다.
- `validate_log_lambda` 함수에서 로그 무결성 검증을 실행하며 해당 검증에 실패할 경우
  - `spike-log-bucket`에 이상데이터를 저장합니다.
  - 지정된 Discord Webhook 채널에 해당 사항을 공지합니다.

#### `monitoring-service.tf`

<div style="text-align: center;"><img src="../assets/final-architecture-part-4.png" alt="isolated" width="600"/></div>

- 모니터링 서비스인 Grafana를 구동하기 위한 EC2 서버를 생성합니다.
- 해당 .tf 파일은 인스턴스가 위치하는 VPC, Subnet, Security Group 등과 같은 리소스들에 대한 정의를 포함하고 있습니다.
- Athena에서 쿼리할 데이터를 미리 준비해주는 Crawler에 대한 정의 또한 포함합니다.
- Route53에서 EC2 인스턴스의 IP 및 DNS 주소를 사용자 도메인의 A-Record로 생성합니다.

#### `variables.tf`
- 리소스들이 활용할 수 있는 변수들에 대한 선언을 담고 있는 .tf 파일입니다.

---
## Terraform 스크립트 실행 및 테스트 순서
