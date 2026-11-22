-- 조회만으로 동시성 방지 불가. 실제 생성은 04의 레인 잠금 후 재검사 필수.
-- 05 직후 -92001의 11~12시는 1행, 12~13시는 0행(맞닿은 경계 허용).
SELECT r.reservation_id,rl.lane_id,r.start_time,r.end_time,r.status
FROM reservation r JOIN reservation_lane rl ON rl.reservation_id=r.reservation_id
WHERE rl.lane_id=-92001 AND r.status<>'CANCELLED'
AND r.start_time<DATE '2030-01-15'+12/24
AND DATE '2030-01-15'+11/24<r.end_time;
SELECT r.reservation_id FROM reservation r JOIN reservation_lane rl
ON rl.reservation_id=r.reservation_id
WHERE rl.lane_id=-92001 AND r.status<>'CANCELLED'
AND r.start_time<DATE '2030-01-15'+13/24
AND DATE '2030-01-15'+12/24<r.end_time;
-- 전체 기존 데이터 충돌 진단. 같은 예약 내부 레인 중복은 PK가 차단.
SELECT a.reservation_id first_id,b.reservation_id second_id,al.lane_id
FROM reservation a JOIN reservation_lane al ON al.reservation_id=a.reservation_id
JOIN reservation_lane bl ON bl.lane_id=al.lane_id AND bl.reservation_id>a.reservation_id
JOIN reservation b ON b.reservation_id=bl.reservation_id
WHERE a.status<>'CANCELLED' AND b.status<>'CANCELLED'
AND a.start_time<b.end_time AND b.start_time<a.end_time;
