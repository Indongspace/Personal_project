# 새로 만든 쿼리
# 데이터의 기간은 2022년 8월 1일부터 2023년 1월 20일까지 : 임시로. 쿼리가 완성되면 전체 일자로 확대
# 분류기준 1) 신규유저(New) : 제품을 처음 사용하는 유저 / 2) 기존유저(Current) : 제품을 지속적으로 사용하는 유저 / 3) 복귀유저(Resurrected) : 과거에 사용 -> 비활성 -> 다시 제품을 사용한 유저 / 4) 휴면유저(Dormant) : 일정 기간 제품을 사용하지 않은 비활성화 사용자

-- app_logs 데이터의 베이스 -- 
WITH base AS (
  SELECT
    user_pseudo_id,
    DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
    *EXCEPT(user_pseudo_id, event_timestamp, event_date)
  FROM advanced.app_logs
  WHERE
    event_date BETWEEN '2022-08-01' AND '2022-11-01'
) 
-----------------------------------------------------------
-- 유저 로그 기록 (첫날, 마지막날, 접속 수) 구하는 쿼리 --
, user_activity AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_event_date,
    MAX(event_date) AS last_event_date,
    COUNT(DISTINCT event_date) AS active_days
  FROM base
  GROUP BY
    user_pseudo_id
)
-----------------------------------------------------------------
-- 기존유저(Current, 제품을 지속적으로 사용하는 유저) 구하는 쿼리 -- 
# 3주 이상 연속 활동한 유저를 기존(Current) 유저로 설정
, current_week_activity AS (
  SELECT
    DISTINCT user_pseudo_id
  FROM base
  WHERE
    DATE_DIFF((SELECT MAX(event_date) FROM base), event_date, WEEK) = 0 -- 현재 주에 사용한 유저 
), last_two_weeks_activity AS (
  SELECT
    user_pseudo_id,
    MAX(CASE WHEN DATE_DIFF((SELECT MAX(event_date) FROM base), event_date, WEEK) = 1 THEN 1 ELSE 0 END) AS last_week_active, -- 1주전 접속
    MAX(CASE WHEN DATE_DIFF((SELECT MAX(event_date) FROM base), event_date, WEEK) = 2 THEN 1 ELSE 0 END) AS two_weeks_ago_active -- 2주전 접속
  FROM base
  GROUP BY
    user_pseudo_id
), current_user_classification AS (
  SELECT
    DISTINCT user_pseudo_id
  FROM current_week_activity
  WHERE
    user_pseudo_id IN (SELECT user_pseudo_id FROM last_two_weeks_activity WHERE last_week_active = 1 AND two_weeks_ago_active = 1) -- 지난 2주 연속 사용한 유저와 현재 주에 사용한 유저 교집합 (결국 3주 연속 사용유저)
)
----------------------------------------------------------------------------------------------
-- 휴면유저(Dormant, 일정 기간 제품을 사용하지 않은 비활성화 사용자) 구하는 쿼리 --
# 비활성화 기준 : 30일 이상 미사용 
, dormant_user_classification AS (
  SELECT
    user_pseudo_id,
    MAX(event_date) AS last_active_date
  FROM base
  GROUP BY
    user_pseudo_id
  HAVING
    DATE_DIFF((SELECT MAX(event_date) FROM base), last_active_date, DAY) > 30
)
-----------------------------------------------------------------------------------------------------
-- 복귀유저(Resurrected, 과거에 사용 -> 비활성 -> 다시 제품을 사용한 유저) 구하는 쿼리 --








---------------------------------------------------------------------------------------------
-- (복귀유저 없는) 유저 분류 쿼리 --
, user_classification_result AS (
  SELECT
    ua.user_pseudo_id,
    CASE
      WHEN ua.first_event_date = (SELECT MAX(event_date) FROM base) THEN 'New' -- 오늘 처음 사용 : 신규유저(New)
      WHEN cu.user_pseudo_id IS NOT NULL THEN 'Current' -- 이번 주 활동, 지속 사용 유저 : 기존유저(Current)
      WHEN du.user_pseudo_id IS NOT NULL THEN 'Dormant' -- 30일 이상 비활성화 : 휴면유저(Dormant)
    END AS user_classification
  FROM user_activity AS ua
  LEFT JOIN current_user_classification AS cu
  ON ua.user_pseudo_id = cu.user_pseudo_id
  LEFT JOIN dormant_user_classification AS du
  ON ua.user_pseudo_id = du.user_pseudo_id
)
---------------------------------------------------------------------
-- 검증용 쿼리(분류된 개수와 그 종류 출력) --
SELECT
  user_pseudo_id,
  COUNT(DISTINCT user_classification) AS num_classifications,
  ARRAY_AGG(user_classification) AS classifications
FROM user_classification_result
GROUP BY
  user_pseudo_id
HAVING
  num_classifications > 2
------------------------------------- 끝 -------------------------------------
