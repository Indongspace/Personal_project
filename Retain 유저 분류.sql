# 새로 만든 쿼리
# 데이터의 기간은 2022년 8월 1일부터 2023년 1월 20일까지
WITH base AS (
  SELECT
    user_pseudo_id,
    DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
    *EXCEPT(user_pseudo_id, event_timestamp, event_date)
  FROM advanced.app_logs
  WHERE
    event_date BETWEEN '2022-08-01' AND '2022-11-01'
), user_activity AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS first_event_date,
    MAX(event_date) AS last_event_date,
    COUNT(DISTINCT event_date) AS active_days
  FROM base
  GROUP BY
    user_pseudo_id
), current_week_activity AS (
# 이번 주에 최소 1회 활동한 유저를 기존(Current) 유저
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT event_date) AS days_active_this_week
  FROM base
  WHERE
    DATE_DIFF((SELECT MAX(event_date) FROM base), event_date, WEEK) = 0
  GROUP BY
    user_pseudo_id
), dormant_user_check AS (
# 비활성화 기준 : 30일 이상 미사용
  SELECT
    user_pseudo_id,
    MAX(event_date) AS last_active_date
  FROM base
  GROUP BY
    user_pseudo_id
  HAVING
    DATE_DIFF((SELECT MAX(event_date) FROM base), last_active_date, DAY) > 30
)

