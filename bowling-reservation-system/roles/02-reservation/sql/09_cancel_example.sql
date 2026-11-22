-- 08에서 생성한 SQL*Plus 바인드 사용. 독립 실행 시 원하는 개인 시연 ID로 먼저 바인드 설정.
BEGIN
 R2_CANCEL_RESERVATION(:new_reservation_id);
END;
/
SELECT reservation_id,status FROM reservation WHERE reservation_id=:new_reservation_id;
-- 핵심 UPDATE는 04 내부의 UPDATE reservation SET status='CANCELLED' ...
-- 단독 UPDATE 대신 레인/예약 잠금과 이용 기록 확인을 포함하는 프로시저 사용.
-- COMMIT; -- 호출자가 생성/취소 트랜잭션 경계를 결정한다.
