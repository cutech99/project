-- 호환 스키마. LEFT JOIN으로 미배정 예약도 노출. 한 예약당 한 행.
SELECT r.reservation_id,m.name,r.start_time,r.end_time,r.person_count,
 r.status AS reservation_status,r.created_at,COUNT(rl.lane_id) AS assigned_lanes,
 CEIL(r.person_count/4) AS minimum_lanes,
 LISTAGG(TO_CHAR(l.lane_no),', ') WITHIN GROUP(ORDER BY l.lane_no) AS lane_numbers
FROM reservation r JOIN member m ON m.member_id=r.member_id
LEFT JOIN reservation_lane rl ON rl.reservation_id=r.reservation_id
LEFT JOIN lane l ON l.lane_id=rl.lane_id
GROUP BY r.reservation_id,m.name,r.start_time,r.end_time,r.person_count,r.status,r.created_at
ORDER BY r.start_time,r.reservation_id;
-- 일자 필터: 함수를 컬럼에 씌우지 않는 반열린 구간.
SELECT r.* FROM reservation r
WHERE r.start_time>=DATE '2030-01-15' AND r.start_time<DATE '2030-01-16'
AND r.member_id=-92001 ORDER BY r.start_time;
-- 비취소 예약 중 배정 부족: 기대 0행 (기존 데이터가 있으면 점검 필요).
SELECT r.reservation_id,r.person_count,COUNT(rl.lane_id) lane_count
FROM reservation r LEFT JOIN reservation_lane rl ON rl.reservation_id=r.reservation_id
WHERE r.status<>'CANCELLED'
GROUP BY r.reservation_id,r.person_count
HAVING COUNT(rl.lane_id)<CEIL(r.person_count/4);
