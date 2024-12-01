# 새로 만든 쿼리
# 데이터의 기간은 2022년 8월 1일부터 2023년 1월 20일까지 
# 분류기준 1) 신규유저(New) : 제품을 처음 사용하는 유저 / 2) 기존유저(Current) : 제품을 지속적으로 사용하는 유저 / 3) 복귀유저(Resurrected) : 과거에 사용 -> 비활성 -> 다시 제품을 사용한 유저 / 4) 휴면유저(Dormant) : 일정 기간 제품을 사용하지 않은 비활성화 사용자

-- app_logs 데이터의 베이스 -- 
WITH base AS (
  SELECT
    user_pseudo_id,
    DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
    *EXCEPT(user_pseudo_id, event_timestamp, event_date)
  FROM advanced.app_logs
)
-----------------------------------------------------------
-- 유저 로그 기록 (첫날, 마지막날, 접속 수) 구하는 쿼리 --
, user_firstlast_activity_and_connectioncnt AS (
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
# 2주 이상 연속 활동한 유저를 기존(Current) 유저로 설정 - type1은 과거 2주 이상으로 연속 사용한 유저 - type2는 최근 2주 연속 사용한 유저
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
), current_user_type1 AS (
  -- 2주 이상 연속으로 접속한 기록이 있는 유저(과거)
  SELECT
    event_date
  FROM base
), current_user_type2 AS (
  -- 최근 2주 연속 접속한 기록이 있는 유저(최신날짜로부터 2주)
  SELECT
    event_date
  FROM base
), current_user_classification AS (
  SELECT
    DISTINCT user_pseudo_id
  FROM current_week_activity
  WHERE
    user_pseudo_id IN (SELECT user_pseudo_id FROM last_two_weeks_activity WHERE last_week_active = 1 AND two_weeks_ago_active = 1) -- 지난 2주 연속 사용한 유저와 현재 주에 사용한 유저 교집합 (결국 3주 연속 사용유저)
)
----------------------------------------------------------------------------------------------
-- 휴면유저(Dormant, 일정 기간 제품을 사용하지 않은 비활성화 사용자) 구하는 쿼리 --
# 비활성화 기준 : 최근 30일 이상 미사용 
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
# 조건1. 과거 사용 이력이 있음(한 번 이상 제품을 사용한 기록이 있음) / 조건2. 비활성 기간(30일 이상 연속 미접속 상태였음) / 조건3. 재접속 후 활동 중(비활성화 이후 재접속했고, 최근 30일 이내 활동. 최근 30일 이후가 마지막이면 휴면유저로 분류되기 때문)
, user_activity AS (
  SELECT
    user_pseudo_id,
    event_date,
    LAG(event_date) OVER(PARTITION BY user_pseudo_id ORDER BY event_date) AS prev_event_date
  FROM base
)
, inactive_periods AS (
  SELECT
    *,
    DATE_DIFF(event_date, prev_event_date, DAY) AS inactivity_days
  FROM user_activity
)
, resurrected_user_classification AS (
  SELECT
    ip.user_pseudo_id
    --ip.event_date,
    --ip.prev_event_date,
    --ip.inactivity_days,
    --la.last_active_date
  FROM inactive_periods AS ip
  INNER JOIN (SELECT user_pseudo_id, MAX(event_date) AS last_active_date FROM base GROUP BY user_pseudo_id) AS la
  ON ip.user_pseudo_id = la.user_pseudo_id
  WHERE
    ip.inactivity_days > 30 AND -- 30일 이상 비활성화
    DATE_DIFF((SELECT MAX(event_date) FROM base), la.last_active_date, DAY) <= 30 -- 최근 30일 이내 재접속
)
---------------------------------------------------------------------------------------------
-- 유저 분류 쿼리 --
, user_classification_result AS (
  SELECT
    ua.user_pseudo_id,
    CASE
      WHEN DATE_DIFF((SELECT MAX(event_date) FROM base), ua.first_event_date, DAY) <= 7 THEN 'New' -- 가입일이 최근 일주일 이내 : 신규유저(New)
      WHEN cu.user_pseudo_id IS NOT NULL THEN 'Current' -- 이번 주 활동, 지속 사용 유저 : 기존유저(Current)
      WHEN du.user_pseudo_id IS NOT NULL THEN 'Dormant' -- 30일 이상 비활성화 : 휴면유저(Dormant)
      WHEN ru.user_pseudo_id IS NOT NULL THEN 'Resurrected' -- 과거에 사용 -> 30일 이상 비활성화 -> 최근 30일 이내 재접속 : 복귀유저(Resurrected)
      ELSE 'Unclassified' -- 미분류 유저 
    END AS user_classification
  FROM user_firstlast_activity_and_connectioncnt AS ua
  LEFT JOIN current_user_classification AS cu
  ON ua.user_pseudo_id = cu.user_pseudo_id
  LEFT JOIN dormant_user_classification AS du
  ON ua.user_pseudo_id = du.user_pseudo_id
  LEFT JOIN resurrected_user_classification AS ru
  ON ua.user_pseudo_id = ru.user_pseudo_id
)
---------------------------------------------------------------------
-- 검증용 쿼리(분류된 개수와 그 종류 출력) --
-- SELECT
--   user_pseudo_id,
--   COUNT(DISTINCT user_classification) AS num_classifications,
--   ARRAY_AGG(user_classification) AS classifications
-- FROM user_classification_result
-- GROUP BY
--   user_pseudo_id
-- HAVING
--   num_classifications > 2
------------------------------------- 끝 -------------------------------------

SELECT
  user_classification,
  COUNT(user_pseudo_id) AS user_cnt
FROM user_classification_result
GROUP BY
  user_classification


