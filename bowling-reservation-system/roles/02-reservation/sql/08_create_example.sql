-- 05 이후 별도 예제: 기존 10~12시 다음인 12~14시, 레인2개, 6명.
-- 이 스크립트 자체는 저장하지 않음. 개인 DB에서 저장 시 아래 COMMIT을 직접 선택.
VARIABLE new_reservation_id NUMBER
BEGIN
 R2_CREATE_RESERVATION(-92001,DATE '2030-01-15'+12/24,DATE '2030-01-15'+14/24,
 6,SYS.ODCINUMBERLIST(-92001,-92002),:new_reservation_id);
END;
/
PRINT new_reservation_id
SELECT * FROM reservation WHERE reservation_id=:new_reservation_id;
SELECT * FROM reservation_lane WHERE reservation_id=:new_reservation_id;
-- COMMIT; -- 예약과 레인 배정이 함께 확정. 시연 기본값은 미커밋.
-- ROLLBACK; -- 현재 세션의 05 이후 시연 데이터도 함께 되돌림.
