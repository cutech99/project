-- 개인 전용 세션, 자동 커밋 OFF. 의도적으로 COMMIT하지 않음.
-- 6~8번 스크립트를 같은 세션에서 실행. 연결 종료 시 COMMIT 선택하지 말 것.
-- 음수는 시연 전용 ID(기존 시퀀스와 분리). 충돌 시 원본을 수정하지 않고 중단.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET SERVEROUTPUT ON
DECLARE n NUMBER; v_id NUMBER;
BEGIN
 SAVEPOINT r2_demo_seed;
 SELECT (SELECT COUNT(*) FROM member WHERE member_id=-92001)
 + (SELECT COUNT(*) FROM lane WHERE lane_id IN (-92001,-92002,-92003,-92004)
 OR lane_no IN (92001,92002,92003,92004)) INTO n FROM dual;
 IF n>0 THEN RAISE_APPLICATION_ERROR(-20020,'시연 ID 충돌: 새 개인 스키마 사용'); END IF;
 INSERT INTO member(member_id,name,phone,grade) VALUES(-92001,'예약시연회원','DEMO-R2-92001','NORMAL');
 INSERT INTO lane(lane_id,lane_no,status) VALUES(-92001,92001,'AVAILABLE');
 INSERT INTO lane(lane_id,lane_no,status) VALUES(-92002,92002,'AVAILABLE');
 -- 아래 두 값은 시연용 비가용 상태, 공통 CHECK가 있으면 먼저 합의/조정 필요.
 INSERT INTO lane(lane_id,lane_no,status) VALUES(-92003,92003,'MAINTENANCE');
 INSERT INTO lane(lane_id,lane_no,status) VALUES(-92004,92004,'UNAVAILABLE');
 R2_CREATE_RESERVATION(-92001,DATE '2030-01-15'+10/24,DATE '2030-01-15'+12/24,
  6,SYS.ODCINUMBERLIST(-92001,-92002),v_id);
 DBMS_OUTPUT.PUT_LINE('6명 / 레인2개 예약 ID='||v_id);
EXCEPTION WHEN OTHERS THEN ROLLBACK TO r2_demo_seed; RAISE;
END;
/
