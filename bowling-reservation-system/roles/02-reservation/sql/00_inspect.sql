-- 읽기 전용. SQL*Plus / SQLcl / SQL Developer(F5). 접속정보는 저장하지 않는다.
SELECT table_name, column_name, data_type, data_length, nullable, data_default
FROM user_tab_columns WHERE table_name IN ('MEMBER','LANE','RESERVATION','RESERVATION_LANE','USAGE')
ORDER BY table_name,column_id;
SELECT table_name,constraint_name,constraint_type,status,validated,search_condition
FROM user_constraints WHERE table_name IN ('MEMBER','LANE','RESERVATION','RESERVATION_LANE','USAGE')
ORDER BY table_name,constraint_name;
SELECT constraint_name,table_name,column_name,position FROM user_cons_columns
WHERE table_name IN ('RESERVATION','RESERVATION_LANE') ORDER BY constraint_name,position;
SELECT sequence_name,last_number,increment_by FROM user_sequences
WHERE sequence_name IN ('SEQ_RESERVATION_ID','SEQ_MEMBER_ID','SEQ_LANE_ID','SEQ_USAGE_ID','USAGE_SEQ');
SELECT lane_id,lane_no,status FROM lane ORDER BY lane_id;
SELECT reservation_id,member_id,res_date,status,created_at FROM reservation ORDER BY reservation_id;
