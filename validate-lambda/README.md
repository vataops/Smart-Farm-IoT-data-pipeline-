# **validate_lambda 구현**

### **2022.07.29 커밋**
- S3에서 데이터 수집 코드
- S3 데이터의 key 값 로그로 받아오기
- Serverless Framework로 배포 자동화
---
### **2022.08.01 커밋**
- **1차 커밋**
    - `pandas` 모듈을 Lambda에 추가 (Lambda Layer)
        - AWSDataWrangler-Python38 Layer 사용
    - `pandas` 모듈 사용하여 `parquet` 파일 읽어오기
        - 실패..

- **2차 커밋**
    - io 모듈을 사용하여 `parquet` 파일 읽기
    - `.head(1)` 함수를 사용하여 첫번째 줄 불러오기
---
### **2022.08.02 커밋**
- **1차 커밋**
    - 비정상적 데이터 정제 기준 추가
        - `pyarrow.parquet` 모듈 사용
- **2차 커밋**
    - 데이터 정제 기준 수정
        - 이전 코드에서 오류 -> `pandas` 모듈을 사용하여 다시 수정
- **3차 커밋**
    - 데이터 정제 기준 수정
        - 정삭적인 데이터를 제외 해야하는데, 모든 데이터를 들고 옴.
        - 비정상적인 데이터만 가져오도록 기준 수정
    - 비정상적인 데이터 모음
        - `pandas.concat` 함수를 사용하여 데이터 모으기
    - 데이터 모음을 `parquet` 파일로 변환
        - `pandas.DataFrame.to_parquet` 함수 사용