# Terraform을 활용한 아키텍쳐 IaC화

<a href="https://www.terraform.io/"><img src="../assets/Terraform.png" alt="isolated" width="200"/></a>

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

#### `ec2.tf`
- 모니터링 서비스인 Grafana를 구동하기 위한 EC2 서버 생성을 위한 .tf 파일입니다. 
- 해당 .tf 파일은 인스턴스가 위치하는 VPC, Subnet, Security Group 등과 같은 리소스들에 대한 정의 또한 포함하고 있습니다.

#### `kinesis-api-gw.tf`
- Kinesis Data Streams 서비스에 대한 진입점(엔드포인트) 확보를 위한 API Gateway 생성을 책임지는 .tf 파일입니다.

#### `kinesis.tf`
- Kinesis Data Stream 및 Data Firehose 생성을 위한 .tf 파일입니다.
- Firehose의 정상적인 실행을 위해 필요한 권한 및 역할 생성을 책임지는 리소스들이 포함되어 있습니다.

#### `glue.tf`
- AWS 매니지드 ETL 서비스인 Glue와 관련된 리소스 생성을 위한 .tf 파일입니다.
- Firehose에서 데이터 포맷 변환을 위한 권한을 부여하는 역할 정의를 포함합니다.
- Athena에서 쿼리할 데이터를 미리 준비해주는 Crawler에 대한 정의 또한 포함합니다.

#### `validate-lambda.tf`
- S3에 업로드되는 `.parquet` 형식의 데이터를 읽어와 이상 데이터 유무를 판별하는 기능을 수행하는 람다 함수 생성을 위한 .tf 파일입니다.
- Terraform의 archive 기능을 사용하여 `validate-lamdba` 폴더 내의 함수 코드의 변경이 있을때 마다 새로운 배포를 진행할 수 있습니다.
- 추가적으로 python의 pandas 패키지 사용을 위하여 AWS에서 제공하는 DataWrangler 레이어에 대한 참조 또한 확인할 수 있습니다.

#### `test-lambda.tf`
- 스트리밍 센서 데이터를 모방하는 람다함수 생성을 위한 .tf 파일입니다.
- 함수 실행과 관련된 추가적인 패키지 사용을 위해 `python.zip`으로 표현되는 레이어를 참조합니다.
- `validate-lambda`와 마찬가지로 archive를 사용한 코드 변경이 새로운 배포로 이어지게 할 수 있습니다.

#### `test-lambda-api-gw.tf`
- `test-lambda` 함수를 트리거하는 엔드포인트 생성을 위한 API Gateway가 선언되어 있는 .tf 파일입니다.

#### `athena.tf`
- AWS Athena 엔진을 활용하기 위한 Workgroup, Data Catalog 등을 선언하는 .tf 파일입니다.

#### `variables.tf`
- 리소스 들이 활용할 수 있는 변수들에 대한 선언을 담고 있는 .tf 파일입니다.

---
## Terraform 스크립트 실행 및 테스트 순서
