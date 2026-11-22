-- 기존 예약의 실제 시작/종료/인원을 담당자 확인으로 복원한 뒤 실행.
-- 임의 기본값/자동 UPDATE 없음. NULL 또는 규칙 위반 행이 있으면 중단한다.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
DECLARE n NUMBER;
BEGIN
 SELECT COUNT(*) INTO n FROM reservation
 WHERE start_time IS NULL OR end_time IS NULL OR person_count IS NULL
 OR person_count<1 OR person_count<>TRUNC(person_count)
 OR end_time<=start_time OR end_time>start_time+2/24 OR res_date<>start_time;
 IF n>0 THEN RAISE_APPLICATION_ERROR(-20004,'기존 예약 보완 필요: NOT NULL 적용 중단'); END IF;
END;
/
ALTER TABLE RESERVATION MODIFY (START_TIME NOT NULL, END_TIME NOT NULL, PERSON_COUNT NOT NULL);
