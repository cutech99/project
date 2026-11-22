# 2번 담당 — 예약 관리 · 레인 배정

## 담당 목표
`RESERVATION`과 `RESERVATION_LANE`을 중심으로 **예약 등록부터 레인 배정, 조회, 취소**까지 구현합니다. 이 프로젝트의 가장 중요한 N:N 관계 처리 담당입니다.

## 현재 구현 현황

Oracle 19c용 SQL 11개와 설계·실행 문서 2개를 작성했습니다. **파일 작성 및 정적 점검 완료이며, Oracle 실행 검증은 아직 하지 않았습니다.** Spring Boot 화면과 Java 코드는 후속 작업입니다.

- [SQL 실행 순서·테스트 방법](docs/README_SQL.md)
- [현재 Oracle/H2 차이와 목표 스키마](docs/SCHEMA_COMPARISON.md)

### SQL 파일 목록

| 파일 | 용도 |
|---|---|
| [00_inspect.sql](sql/00_inspect.sql) | 기존 컬럼·제약·상태·시퀀스 확인 |
| [01_create_empty.sql](sql/01_create_empty.sql) | 예약 테이블이 모두 없는 개인 DB의 CREATE 경로 |
| [02_alter_existing.sql](sql/02_alter_existing.sql) | 1번 기존 Oracle 예약 테이블에 컬럼 추가 |
| [03_validate_existing.sql](sql/03_validate_existing.sql) | 기존 예약 보완 확인 후 NOT NULL 적용 |
| [04_transaction_api.sql](sql/04_transaction_api.sql) | 레인 잠금·중복 검사·생성/취소 프로시저 |
| [05_dummy_data.sql](sql/05_dummy_data.sql) | 가상 회원·레인 및 6명/레인2개 예약 |
| [06_select_join.sql](sql/06_select_join.sql) | 예약·회원·레인 JOIN 및 배정 수 조회 |
| [07_overlap_check.sql](sql/07_overlap_check.sql) | 시간 중복과 경계시간 조회 |
| [08_create_example.sql](sql/08_create_example.sql) | 생성 및 다중 레인 배정 호출 예제 |
| [09_cancel_example.sql](sql/09_cancel_example.sql) | 취소 UPDATE를 포함한 프로시저 호출 |
| [10_tests.sql](sql/10_tests.sql) | 정상·오류·FK·중간 실패 롤백 테스트 |

### 개인 Oracle 시연 순서

1. `00`으로 실제 스키마를 확인합니다.
2. 예약 테이블이 없으면 `01`, 1번 원본 테이블이 있으면 `02` → 기존 예약의 실제 시간·인원 보완 → `03`을 실행합니다. 두 경로는 택일합니다.
3. `04`를 실행하고 컴파일 오류를 확인합니다. 부모 테이블과 1번 정의의 `USAGE`가 필요합니다.
4. DDL 완료 후 시연 전용 세션에서 `05` → `06`/`07` → `10` 순으로 실행합니다. 추가 시연은 `08` → `09`입니다.
5. 기본 마무리는 `ROLLBACK`입니다. 시연 SQL은 자동 COMMIT하지 않습니다. DDL에는 암묵적 COMMIT이 있으므로 시연 데이터 입력 후 DDL을 실행하지 않습니다.

공용 DB 적용, 기존 테이블 DROP/데이터 DELETE, 접속 비밀번호 저장은 하지 않습니다. 커밋·푸시는 승인 후 진행합니다. 자세한 사전조건과 예상 결과는 실행 가이드를 확인합니다.

### 현행 호환안과 팀 합의 사항

현재 실행 SQL은 1번 Oracle의 `RES_DATE`, `STATUS`, `CREATED_AT`을 유지하고 `START_TIME`, `END_TIME`, `PERSON_COUNT`를 추가합니다. 신규 예약의 `RES_DATE`는 시작시각과 동일하게 저장합니다. 예약은 `RESERVED`/`CANCELLED`, 예약 가능한 시설은 `LANE.STATUS='AVAILABLE'`을 사용합니다.

요구사항의 `RESERVATION_STATUS` 및 3번의 한글 상태는 **합의할 목표안**입니다. 이번 SQL에 한글 상태를 섞거나 3번 앱을 그대로 연결하면 호환되지 않습니다. 레인·회원·USAGE 구조와 시퀀스도 함께 합의해야 합니다.

## 남은 작업 체크리스트

아래 미완료 체크는 Oracle 실검증 및 앱 통합 기준입니다. 해당 SQL 작성 여부는 위 산출물 목록을 참고합니다.
### 1. 예약 화면
- [ ] 예약 목록 화면 (날짜·회원·상태 필터)
- [ ] 예약 등록 화면: 회원, 시작/종료 시간, 인원, 레인 선택
- [ ] 예약 상세 화면: 예약 상태, 인원, 배정 레인 확인
- [ ] 예약 취소 기능 및 취소 사유/확인 UI 범위 합의
- [ ] 예약 성공/실패 메시지 표시

### 2. 예약 DB 처리
- [ ] `MEMBER`에서 예약자 조회
- [ ] `RESERVATION` INSERT 및 목록/상세 SELECT
- [ ] `RESERVATION_LANE`에 선택 레인 여러 개 INSERT
- [ ] 예약 + 레인 배정 작업을 **한 트랜잭션으로 처리** (일부만 저장되지 않도록)
- [ ] 취소 상태 최종 합의 및 앱 연동 (현재 SQL은 `STATUS='CANCELLED'`, 목표안은 `RESERVATION_STATUS` 검토)
- [ ] 예약 상태 변경이 3번의 이용 처리와 충돌하지 않도록 협의

### 3. 비즈니스 규칙/검증
- [ ] 시작시간 < 종료시간
- [ ] 예약시간 최대 2시간
- [ ] 예약인원 1명 이상
- [ ] 레인 1개당 4명 기준으로 충분한 레인 수 배정 (`ceil(person_count/4)`)
- [ ] `점검중`, `사용불가` 레인 배정 거부
- [ ] **시간 중복 거부**: 기존.start < 신규.end AND 신규.start < 기존.end
- [ ] 시간 겹침 비교에서는 `취소` 예약 제외
- [ ] 같은 예약에 같은 레인 두 번 추가 방지(복합 PK)
- [ ] 동시에 같은 레인을 예약하는 경쟁 상황의 처리 방안 논의

## 담당 테이블과 관계
- 직접 관리: `RESERVATION`, `RESERVATION_LANE`
- 참조: `MEMBER`, `LANE`
- 관계: `MEMBER 1:N RESERVATION`; `RESERVATION N:N LANE` (연결 테이블 사용)

## 화면 (예정)
- `/reservations` — 예약 목록
- `/reservations/new` — 예약 등록
- `/reservations/{id}` — 예약 상세
- 예약 취소: 팀과 HTTP 방식/URL을 협의

## 다른 담당자와 협업
- **1번:** 회원 선택 및 DB 공통 연결
- **3번:** 레인 시설 상태 조회, 예약 후 이용 시작 가능 시점·상태 변경
- **4번:** 예약 화면의 입력 컴포넌트와 상태 표시

## 필수 테스트 시나리오
- [ ] 1~4명 예약 → 레인 1개 이상 배정
- [ ] 6명 예약 → 최소 2개 레인 배정
- [ ] 같은 레인을 겹치는 시간에 예약 → 실패 메시지 표시
- [ ] 점검/사용불가 레인 선택 → 예약 거부
- [ ] 2시간 초과 예약 → 거부
- [ ] 예약 처리 중 레인 배정 실패 → 예약도 롤백
- [ ] 취소한 예약이 신규 예약의 충돌 판정에 포함되지 않음

## 이후 Spring Boot 구현 순서

1. 1번·3번과 공통 스키마/상태/시퀀스/시간대/잠금 순서를 확정합니다.
2. 예약 DTO 및 조회 Repository, 회원·레인 선택 조회를 구현합니다.
3. Service의 생성 트랜잭션에 검증 → 정렬된 레인 잠금 → 중복 재검사 → 예약/배정 저장을 연결합니다.
4. Controller와 예약 등록·목록·상세 화면, 오류 메시지를 구현합니다.
5. 취소 트랜잭션과 이용 기록 확인을 연결합니다.
6. 개인 Oracle에서 경계시간·FK·롤백·동시 요청을 검증한 뒤 3번 이용 기능과 4번 UI·통계를 통합합니다.

Oracle DDL/PLSQL 컴파일, 실제 데이터 입력 및 두 세션 동시성은 미검증입니다. 테스트 출력과 성공 증빙은 개인 Oracle 실행 후 기록합니다.
