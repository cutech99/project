-- 01 또는 02+03 -> 04 -> 05 이후 같은 개인 세션에서 실행. 자동 COMMIT OFF.
-- 실패는 ORA-20999로 전파. 전체 성공/실패 모두 테스트 저장점으로 되돌린다.
-- 05 더미는 남아 있으며 마지막 ROLLBACK으로 제거(기존 커밋 데이터는 보존).
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET SERVEROUTPUT ON
DECLARE
 v_id NUMBER; v_seed NUMBER; v_n NUMBER; v_before NUMBER; v_after NUMBER;
 v_fk_member NUMBER; v_fk_lane NUMBER;
 PROCEDURE ok(p_condition BOOLEAN,p_label VARCHAR2) IS
 BEGIN
  IF p_condition IS NULL OR NOT p_condition THEN RAISE_APPLICATION_ERROR(-20999,'FAIL: '||p_label); END IF;
  DBMS_OUTPUT.PUT_LINE('PASS: '||p_label);
 END;
 PROCEDURE expect_sql(p_sql VARCHAR2,p_code NUMBER,p_label VARCHAR2) IS
  v_code NUMBER:=0;
 BEGIN
  SAVEPOINT r2_negative;
  BEGIN EXECUTE IMMEDIATE p_sql; EXCEPTION WHEN OTHERS THEN v_code:=SQLCODE; END;
  ROLLBACK TO r2_negative;
  ok(v_code=p_code,p_label||' expected='||p_code||' actual='||v_code);
 END;
 PROCEDURE expect_api(p_people NUMBER,p_start DATE,p_end DATE,p_lanes SYS.ODCINUMBERLIST,
 p_code NUMBER,p_label VARCHAR2,p_member NUMBER DEFAULT -92001) IS
  v_code NUMBER:=0; v_temp NUMBER; v_old NUMBER; v_new NUMBER;
 BEGIN
  SELECT COUNT(*) INTO v_old FROM reservation;
  BEGIN R2_CREATE_RESERVATION(p_member,p_start,p_end,p_people,p_lanes,v_temp);
  EXCEPTION WHEN OTHERS THEN v_code:=SQLCODE; END;
  SELECT COUNT(*) INTO v_new FROM reservation;
  ok(v_code=p_code AND v_old=v_new,p_label||' code='||v_code);
 END;
BEGIN
 SAVEPOINT r2_test_all;
 SELECT MAX(reservation_id) INTO v_seed FROM reservation
 WHERE member_id=-92001 AND start_time=DATE '2030-01-15'+10/24 AND status='RESERVED';
 ok(v_seed IS NOT NULL,'05 정상 예약 존재');
 SELECT COUNT(*) INTO v_n FROM reservation r JOIN reservation_lane rl ON rl.reservation_id=r.reservation_id
 JOIN member m ON m.member_id=r.member_id JOIN lane l ON l.lane_id=rl.lane_id
 WHERE r.reservation_id=v_seed AND r.person_count=6;
 ok(v_n=2,'정상 JOIN 조회: 6명 레인2개');
 expect_api(6,DATE '2030-01-16',DATE '2030-01-16'+1/24,SYS.ODCINUMBERLIST(-92001),-20014,'6명 레인1개 거부');
 expect_api(2,DATE '2030-01-15'+11/24,DATE '2030-01-15'+12/24,SYS.ODCINUMBERLIST(-92001),-20017,'동일 레인 시간 중복 거부');
 expect_api(1,DATE '2030-01-16',DATE '2030-01-16'+1/24,SYS.ODCINUMBERLIST(-92003),-20015,'점검 레인 거부');
 expect_api(1,DATE '2030-01-16',DATE '2030-01-16'+1/24,SYS.ODCINUMBERLIST(-92004),-20015,'사용불가 레인 거부');
 expect_api(0,DATE '2030-01-16',DATE '2030-01-16'+1/24,SYS.ODCINUMBERLIST(-92001),-20011,'API 인원0 거부');
 expect_api(1,DATE '2030-01-16',DATE '2030-01-16'+3/24,SYS.ODCINUMBERLIST(-92001),-20010,'API 3시간 거부');
 expect_api(1,DATE '2030-01-16',DATE '2030-01-16',SYS.ODCINUMBERLIST(-92001),-20010,'0시간 거부');
 expect_api(1,DATE '2030-01-16',DATE '2030-01-15',SYS.ODCINUMBERLIST(-92001),-20010,'역전 시간 거부');
 expect_api(1,DATE '2030-01-16',DATE '2030-01-16'+1/24,SYS.ODCINUMBERLIST(-92001,-92001),-20013,'중복 입력 레인 거부');
 -- CREATE 프로시저를 우회한 INSERT도 CHECK/NOT NULL/PK/FK로 차단되는지 검증.
 SELECT SEQ_RESERVATION_ID.NEXTVAL INTO v_id FROM dual;
 expect_sql('INSERT INTO reservation(reservation_id,member_id,res_date,start_time,end_time,person_count) VALUES('
 ||v_id||',-92001,DATE ''2030-01-16'',DATE ''2030-01-16'',DATE ''2030-01-16''+1/24,0)',-2290,'DB 인원0 CHECK');
 expect_sql('INSERT INTO reservation(reservation_id,member_id,res_date,start_time,end_time,person_count) VALUES('
 ||v_id||',-92001,DATE ''2030-01-16'',DATE ''2030-01-16'',DATE ''2030-01-16''+1/24,1.5)',-2290,'DB 소수 인원 CHECK');
 expect_sql('INSERT INTO reservation(reservation_id,member_id,res_date,start_time,end_time,person_count) VALUES('
 ||v_id||',-92001,DATE ''2030-01-16'',DATE ''2030-01-16'',DATE ''2030-01-16''+3/24,1)',-2290,'DB 2시간 초과 CHECK');
 expect_sql('INSERT INTO reservation(reservation_id,member_id,res_date,start_time,end_time,person_count) VALUES('
 ||v_id||',-92001,DATE ''2030-01-16'',NULL,DATE ''2030-01-16''+1/24,1)',-1400,'DB 시작시간 NOT NULL');
 expect_sql('INSERT INTO reservation_lane VALUES('||v_seed||',-92001)',-1,'복합 PK 중복 차단');
 SELECT NVL(MIN(member_id),0)-1 INTO v_fk_member FROM member;
 SELECT NVL(MIN(lane_id),0)-1 INTO v_fk_lane FROM lane;
 expect_api(1,DATE '2030-01-16',DATE '2030-01-16'+1/24,SYS.ODCINUMBERLIST(-92001),-2291,'없는 회원 FK 및 API 롤백',v_fk_member);
 expect_sql('INSERT INTO reservation_lane VALUES('||v_seed||','||v_fk_lane||')',-2291,'없는 레인 FK');
 -- 헤더 INSERT -> 첫 레인 성공 -> 둘째 레인 FK 실패를 강제로 주입.
 SELECT COUNT(*) INTO v_before FROM reservation_lane;
 SAVEPOINT r2_partial;
 BEGIN
  INSERT INTO reservation(reservation_id,member_id,res_date,start_time,end_time,person_count)
  VALUES(v_id,-92001,DATE '2030-01-16',DATE '2030-01-16',DATE '2030-01-16'+1/24,6);
  INSERT INTO reservation_lane VALUES(v_id,-92001);
  INSERT INTO reservation_lane VALUES(v_id,v_fk_lane);
  RAISE_APPLICATION_ERROR(-20999,'FK 오류가 발생하지 않음');
 EXCEPTION WHEN OTHERS THEN
  IF SQLCODE<>-2291 THEN RAISE; END IF;
  ROLLBACK TO r2_partial;
 END;
 SELECT COUNT(*) INTO v_n FROM reservation WHERE reservation_id=v_id;
 SELECT COUNT(*) INTO v_after FROM reservation_lane;
 ok(v_n=0 AND v_before=v_after,'배정 도중 FK 오류: 헤더/첫 배정 모두 롤백');
 -- 반열린 경계: 10~12시 다음 12~14시 허용. 최대2시간 경계 포함.
 R2_CREATE_RESERVATION(-92001,DATE '2030-01-15'+12/24,DATE '2030-01-15'+14/24,
  1,SYS.ODCINUMBERLIST(-92001),v_id);
 ok(v_id IS NOT NULL,'종료=신규시작, 정확히2시간 허용');
 R2_CANCEL_RESERVATION(v_seed);
 SELECT COUNT(*) INTO v_n FROM reservation_lane WHERE reservation_id=v_seed;
 ok(v_n=2,'취소 시 기존 레인 배정 행 보존');
 R2_CREATE_RESERVATION(-92001,DATE '2030-01-15'+10/24,DATE '2030-01-15'+12/24,
 6,SYS.ODCINUMBERLIST(-92001,-92002),v_id);
 ok(v_id IS NOT NULL,'취소 예약 시간/레인 재사용');
 ROLLBACK TO r2_test_all;
 DBMS_OUTPUT.PUT_LINE('ALL PASS (테스트 변경 롤백 완료, 05 더미는 유지)');
EXCEPTION WHEN OTHERS THEN
 ROLLBACK TO r2_test_all;
 RAISE;
END;
/
