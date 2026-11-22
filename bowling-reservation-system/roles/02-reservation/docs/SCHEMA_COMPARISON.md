# 기존 구조와 예약 SQL 설계

## 확인한 원본
- 프로젝트 `README.md`, `docs/TEAM_GUIDE.md`, `roles/02-reservation/README.md`.
- 1번 `roles/01-db-member/bowling_demo/sql/01_schema_and_dummy.sql`.
- 3번 `roles/03-lane-usage/starter/src/main/resources/db/h2-schema.sql`와 Java Repository, `docs/TEAM_HANDOFF.md`, `docs/DEVELOPMENT_STATUS.md`, starter 인계/연결 문서와 수동 SQL.
- 원본 파일은 변경하지 않았다. 이 문서의 시연안은 팀 합의 완료를 의미하지 않는다.

| 항목 | 1번 현재 Oracle | 3번 H2 및 Java | 통합 문제 |
|---|---|---|---|
| 회원 | NAME, PHONE, EMAIL, GRADE, CREATED_AT | NAME, PHONE, GENDER, JOIN_DATE, MEMBER_GRADE | 회원 조회/INSERT 컬럼 불일치 |
| 레인 | LANE_NO, STATUS, AVAILABLE 기본값 | LANE_NUMBER, LANE_STATUS, 이용가능/점검중/사용불가 CHECK | 3번 Repository를 Oracle에 그대로 연결하면 ORA-00904 |
| 예약 시간 | RES_DATE DATE 하나 | START_TIME/END_TIME TIMESTAMP | 종료시각이 없어 시간 중복/2시간 검사 불가능 |
| 인원 | 없음 | PERSON_COUNT INTEGER | 최소 레인 수 판단 불가능 |
| 예약 상태 | STATUS VARCHAR2(20), RESERVED 기본값 | RESERVATION_STATUS, 예약대기/예약확정/이용중/이용완료/취소 | 컬럼명과 상태 값 모두 다름 |
| 생성일 | CREATED_AT DATE NOT NULL | 없음 | 요구사항의 CREATED_AT은 Oracle에 이미 존재 |
| 예약-레인 | 두 NUMBER, 복합 PK, 각 FK | 같은 관계, BIGINT | 개념적 호환, Oracle 자료형 유지 |
| 이용 | RESERVATION_ID 단일 FK, START_TIME/END_TIME, TOTAL_FEE | LANE_ID 포함, ACTUAL_START_TIME/ACTUAL_END_TIME/USAGE_STATUS, 배정쌍 복합 FK와 UNIQUE | 레인별 이용·예약 상태 동기화 불가, 예약 담당이 수정할 범위 아님 |
| 이용 시퀀스 | SEQ_USAGE_ID | USAGE_SEQ | 1번/3번 ID 정책 합의 필요 |
| 시간 계산 | Oracle DATE, 일 단위 차이 | H2 DATEADD, TIMESTAMP | H2 DDL을 Oracle에 실행 불가 |

## A. 이번 실행 가능한 호환안

Oracle의 기존 컬럼/제약을 유지한다. 새 컬럼은 START_TIME DATE, END_TIME DATE, PERSON_COUNT NUMBER만 추가한다. RES_DATE는 신규 예약 시작시각과 동일하게 저장한다. 날짜만 저장해야 한다는 합의가 생기면 CK_R2_DATE와 INSERT를 함께 재검토해야 한다.

| 실제 컬럼 | 제약/의미 |
|---|---|
| RESERVATION_ID NUMBER | 기존 PK, SEQ_RESERVATION_ID 사용 |
| MEMBER_ID NUMBER | NOT NULL, MEMBER FK |
| RES_DATE DATE | 기존 NOT NULL 유지, 신규 START_TIME과 동일 |
| START_TIME / END_TIME DATE | 최종 NOT NULL, 시작 < 종료 <= 시작+2/24 |
| PERSON_COUNT NUMBER | 최종 NOT NULL, 1 이상 정수 CHECK; NUMBER(정수 정밀도)는 소수 반올림 가능하므로 사용하지 않음 |
| STATUS VARCHAR2(20) | 기존 NOT NULL/기본값 RESERVED 유지; 조회에서 RESERVATION_STATUS 별칭 제공 |
| CREATED_AT DATE | 기존 DEFAULT SYSDATE NOT NULL |
| RESERVATION_LANE | 기존 두 NUMBER NOT NULL, (RESERVATION_ID,LANE_ID) PK 및 각 FK 그대로 |

관계: MEMBER 1:N RESERVATION, RESERVATION 1:N RESERVATION_LANE, LANE 1:N RESERVATION_LANE. 예약과 레인은 연결 테이블을 통한 N:N이다. CASCADE 삭제는 추가하지 않는다.

이번 시연은 예약 RESERVED/CANCELLED와 시설 AVAILABLE만 허용하는 생성 경로를 사용한다. 더미의 MAINTENANCE/UNAVAILABLE은 비가용 값 예시이다. 기존 데이터의 상태 도메인을 모르므로 공통 STATUS CHECK는 임의 추가하지 않았다. 기존 레인 CHECK가 있으면 더미 실행 전 실제 허용값을 확인하고 팀과 조율해야 한다. 한국어 상태와 혼용하면 취소 예약을 잘못 점유 처리하므로 적용하지 않는다.

ALTER 단계는 새 컬럼을 NULL 허용으로 추가해 기존 행을 보존한다. NULL은 CHECK를 통과하므로 이 단계만으로 완료했다고 말할 수 없다. 종료시각/인원은 원본으로 복구할 수 없다. 담당자 확인으로 개별 보완한 다음 03으로 NOT NULL을 적용한다. 스크립트는 자동 보완하지 않는다. 미복원 행은 생성 API가 전체 차단한다.

기존 PK/FK가 원본과 동일한지는 00으로 확인한다. 02는 원본 제약을 재생성하지 않으므로 다른 상태의 DB에 무작정 실행하지 않는다. 시퀀스도 기존 MAX(ID)보다 안전한 번호를 발급하는지 확인해야 하며, 이미 사용 중인 시퀀스를 초기화/변경하지 않는다.

## B. 팀 합의할 목표 스키마 (아직 실행 DDL 없음)

요구한 정확한 구조: RESERVATION(RESERVATION_ID NUMBER PK, MEMBER_ID NUMBER NOT NULL FK, START_TIME DATE NOT NULL, END_TIME DATE NOT NULL, PERSON_COUNT NUMBER NOT NULL, RESERVATION_STATUS VARCHAR2(20 CHAR) NOT NULL, CREATED_AT DATE DEFAULT SYSDATE NOT NULL), RESERVATION_LANE은 현행 유지. 인원 정수/양수, 시간 CHECK는 호환안과 동일. 한글 상태의 바이트 길이 문제를 피하도록 CHAR 길이 의미 제안.

RESERVATION_STATUS의 최종 상태 집합·기본값을 합의한 뒤 CHECK를 정의한다. 3번 제안은 예약대기/예약확정/이용중/이용완료/취소이나 예약대기의 점유 정책도 결정해야 한다. 기존 STATUS와 RES_DATE의 제거/이름변경은 이번 작업에 포함하지 않는다. 두 상태 컬럼을 독립 저장하면 동기화 문제가 생기므로 무조건 추가하지 않는다.

목표 스키마로 전환하려면 1번/3번이 회원·레인·USAGE·시퀀스와 Java SQL까지 함께 이행해야 한다. 조회 별칭만으로 3번의 UPDATE RESERVATION SET RESERVATION_STATUS를 지원할 수 없다. 이번 호환안은 현재 Oracle에서의 예약 시연용이며 3번 앱과 즉시 통합 가능한 스키마가 아니다.

## 업무 규칙의 구현 경계

| 규칙 | 구현 위치 | 한계 |
|---|---|---|
| 1명 이상 정수 | NOT NULL + CHECK | ALTER 후 03 완료 필요 |
| 0시간 초과, 최대2시간 | DATE NOT NULL + CHECK | 날짜 시간은 초 단위, 시간대 정보 없음 |
| 레인당4명 | API에서 배정 수 >= CEIL(인원/4) | 실제 개인별 배치는 저장하지 않음 |
| 여러 레인 | 연결 테이블 여러 INSERT | 모든 배정을 한 트랜잭션으로 수행 |
| 동일 배정 중복 | 복합 PK + API 입력 중복 검사 | 직접 INSERT도 PK로 차단 |
| 점검/사용불가 금지 | 레인 잠금 후 AVAILABLE 화이트리스트 | 시설 변경 경로도 같은 잠금 규약 필요 |
| 동일 레인 시간 중복 | 레인 오름차순 FOR UPDATE 후 별도 충돌 SELECT | CHECK로 다른 행/테이블 검사 불가 |
| 취소 점유 제외 | STATUS <> CANCELLED | 값 변환 합의 전 한글 취소와 혼용 금지 |
| 생성+배정 원자성 | 저장점, 오류 시 ROLLBACK TO, 호출자가 COMMIT | 직접 DML 우회까지 강제하는 DB 트리거는 제공하지 않음 |

인원/시간/배정을 수정하는 경로도 관련 레인을 먼저 잠그고 용량·충돌을 재검사해야 한다. 이번 예제는 생성 후 배정/시간/인원이 불변이라는 전제다. 프로시저 사용 규약 또는 향후 권한 제한 없이 임의 DML까지 업무 규칙을 보장한다고 주장할 수 없다. 취소는 레인→예약 잠금, 이용 기록 있으면 보수적 거부; 시설 변경/이용 시작 경로 역시 레인→예약→이용 기록 순서를 합의한다.
