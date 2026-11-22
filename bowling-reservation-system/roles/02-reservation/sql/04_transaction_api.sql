-- 개인 DB에서 01 또는 02+03 완료 후. STATUS='RESERVED'/'CANCELLED', LANE.STATUS='AVAILABLE'
-- 는 이번 호환 시연의 값이며 팀 최종 상태 규약은 미합의이다.
-- 기존 예약에 시간/인원이 없으면 새 예약 생성도 안전하게 중단한다.
-- 신규 프로시저. 기존 동명 객체가 있으면 덮어쓰지 않고 오류로 중단.
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
CREATE PROCEDURE R2_CREATE_RESERVATION (
 p_member_id IN NUMBER, p_start IN DATE, p_end IN DATE, p_people IN NUMBER,
 p_lanes IN SYS.ODCINUMBERLIST, p_id OUT NUMBER
) AUTHID DEFINER AS
 v_count NUMBER; v_distinct NUMBER; v_status lane.status%TYPE;
 v_id NUMBER;
BEGIN
 SAVEPOINT r2_create_start;
 p_id := NULL;
 IF p_start IS NULL OR p_end IS NULL OR p_end<=p_start OR p_end>p_start+2/24 THEN
  RAISE_APPLICATION_ERROR(-20010,'예약은 0시간 초과 2시간 이하');
 END IF;
 IF p_people IS NULL OR p_people<1 OR p_people<>TRUNC(p_people) THEN
  RAISE_APPLICATION_ERROR(-20011,'인원은 1 이상 정수');
 END IF;
 -- 초기화하지 않은 컬렉션도 예외 처리되어 저장점으로 롤백된다.
 IF p_lanes.COUNT=0 THEN RAISE_APPLICATION_ERROR(-20012,'레인 필요'); END IF;
 SELECT COUNT(*),COUNT(DISTINCT column_value) INTO v_count,v_distinct FROM TABLE(p_lanes);
 IF v_count<>v_distinct THEN RAISE_APPLICATION_ERROR(-20013,'중복 또는 NULL 레인'); END IF;
 IF v_count<CEIL(p_people/4) THEN RAISE_APPLICATION_ERROR(-20014,'배정 레인 부족'); END IF;
 -- 같은 레인에 대해 모든 생성/상태변경 경로가 같은 잠금 규약을 따라야 한다.
 -- 각 SELECT FOR UPDATE 후 별도 SELECT로 READ COMMITTED 최신 커밋을 확인한다.
 FOR x IN (SELECT column_value lane_id FROM TABLE(p_lanes) ORDER BY column_value) LOOP
  SELECT status INTO v_status FROM lane WHERE lane_id=x.lane_id FOR UPDATE;
  SELECT status INTO v_status FROM lane WHERE lane_id=x.lane_id;
  IF v_status<>'AVAILABLE' OR v_status IS NULL THEN
   RAISE_APPLICATION_ERROR(-20015,'이용가능 레인만 배정 가능');
  END IF;
 END LOOP;
 -- 미복원 기존 예약이 있으면 시간 충돌을 신뢰할 수 없으므로 전체 생성 차단.
 SELECT COUNT(*) INTO v_count FROM reservation
 WHERE start_time IS NULL OR end_time IS NULL OR person_count IS NULL;
 IF v_count>0 THEN RAISE_APPLICATION_ERROR(-20016,'기존 예약 시간/인원 복원 필요'); END IF;
 SELECT COUNT(*) INTO v_count FROM reservation r JOIN reservation_lane rl
 ON rl.reservation_id=r.reservation_id
 WHERE rl.lane_id IN (SELECT column_value FROM TABLE(p_lanes))
 AND r.status<>'CANCELLED' AND r.start_time<p_end AND p_start<r.end_time;
 IF v_count>0 THEN RAISE_APPLICATION_ERROR(-20017,'예약 시간 충돌'); END IF;
 SELECT SEQ_RESERVATION_ID.NEXTVAL INTO v_id FROM dual;
 INSERT INTO reservation(reservation_id,member_id,res_date,status,created_at,start_time,end_time,person_count)
 VALUES(v_id,p_member_id,p_start,'RESERVED',SYSDATE,p_start,p_end,p_people);
 FOR x IN (SELECT column_value lane_id FROM TABLE(p_lanes) ORDER BY column_value) LOOP
  INSERT INTO reservation_lane(reservation_id,lane_id) VALUES(v_id,x.lane_id);
 END LOOP;
 p_id:=v_id;
 -- COMMIT은 호출자가 수행. 실패 시 호출 이전의 다른 작업은 보존.
EXCEPTION WHEN OTHERS THEN
 ROLLBACK TO r2_create_start;
 p_id:=NULL;
 RAISE;
END;
/
SHOW ERRORS PROCEDURE R2_CREATE_RESERVATION
CREATE PROCEDURE R2_CANCEL_RESERVATION(p_id IN NUMBER) AUTHID DEFINER AS
 v_status reservation.status%TYPE;
 v_usage_count NUMBER;
BEGIN
 SAVEPOINT r2_cancel_start;
 -- 레인 -> 예약 순서, 여러 레인은 오름차순. 배정은 생성 후 불변이라는 전제.
 FOR x IN (SELECT lane_id FROM reservation_lane WHERE reservation_id=p_id ORDER BY lane_id) LOOP
  SELECT status INTO v_status FROM lane WHERE lane_id=x.lane_id FOR UPDATE;
 END LOOP;
 SELECT status INTO v_status FROM reservation WHERE reservation_id=p_id FOR UPDATE;
 IF v_status='CANCELLED' THEN RETURN; END IF;
 IF v_status<>'RESERVED' THEN RAISE_APPLICATION_ERROR(-20018,'취소 가능한 예약 상태가 아님'); END IF;
 -- 1번 USAGE는 상태 컬럼이 없어 이용 기록이 하나라도 있으면 보수적으로 취소 거부.
 SELECT COUNT(*) INTO v_usage_count FROM usage WHERE reservation_id=p_id;
 IF v_usage_count>0 THEN RAISE_APPLICATION_ERROR(-20019,'이용 기록 존재: 취소 정책 협의 필요'); END IF;
 UPDATE reservation SET status='CANCELLED' WHERE reservation_id=p_id;
 -- 연결 행/이용 기록은 보존. 충돌 조회에서 CANCELLED 제외.
EXCEPTION WHEN OTHERS THEN ROLLBACK TO r2_cancel_start; RAISE;
END;
/
SHOW ERRORS PROCEDURE R2_CANCEL_RESERVATION
-- 컴파일 오류는 SQL*Plus WHENEVER SQLERROR만으로 감지되지 않을 수 있음.
DECLARE n NUMBER;
BEGIN
 SELECT COUNT(*) INTO n FROM user_errors WHERE name IN ('R2_CREATE_RESERVATION','R2_CANCEL_RESERVATION');
 IF n>0 THEN RAISE_APPLICATION_ERROR(-20009,'프로시저 컴파일 오류: USER_ERRORS 확인'); END IF;
END;
/
