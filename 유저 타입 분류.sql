# 1) Weekly Retention을 구하는 쿼리를 바닥부터 스스로 작성해보세요
-- WITH base AS (
--   SELECT
--     DISTINCT 
--       user_id,
--       event_name,
--       DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
--       DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul') AS event_datetime,
--       user_pseudo_id
--   FROM advanced.app_logs
--   WHERE
--     event_date BETWEEN '2022-08-01' AND '2023-08-03'
-- ), first_diff_of_week AS (
--   SELECT
--     *,
--     DATE_DIFF(event_week, first_week, WEEK) AS diff_of_week
--   FROM (
--     SELECT
--       DISTINCT
--         user_pseudo_id,
--         DATE_TRUNC(MIN(event_date) OVER(PARTITION BY user_pseudo_id), WEEK(MONDAY)) AS first_week,
--         DATE_TRUNC(event_date, WEEK(MONDAY)) AS event_week
--     FROM base
--   )
-- ), user_counts AS (
--   SELECT
--     diff_of_week,
--     COUNT(DISTINCT user_pseudo_id) AS user_cnt
--   FROM first_diff_of_week
--   GROUP BY
--     diff_of_week
-- )
-- SELECT
--   diff_of_week,
--   user_cnt,
--   ROUND(SAFE_DIVIDE(user_cnt, first_cnt), 3) AS retention_rate
-- FROM (
--   SELECT
--     *,
--     FIRST_VALUE(user_cnt) OVER(ORDER BY diff_of_week) AS first_cnt
--   FROM user_counts
-- )
-- ORDER BY
--   diff_of_week

# 2) Retain User를 New + Current + Resurrected + Dormant User로 나누는 쿼리를 작성해보세요.
# 신규유저(New) : 제품을 처음 사용하는 유저
# 기존유저(Current) : 제품을 지속적으로 사용하는 유저
# 복귀유저(Resurrected) : 과거에 사용 -> 비활성 -> 다시 제품을 사용한 유저
# 휴면유저(Dormant) : 일정 기간 제품을 사용하지 않은 비활성화 사용자
-- WITH base AS (
--   SELECT
--     DISTINCT
--       user_id,
--       DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
--       DATE_TRUNC(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul'), WEEK(MONDAY)) AS event_week,
--       user_pseudo_id
--   FROM advanced.app_logs
--   WHERE
--     event_date BETWEEN '2022-08-01' AND '2023-08-03'
-- ), user_activity AS (
--   SELECT
--     user_pseudo_id,
--     event_week,
--     LAG(event_week, 1) OVER(PARTITION BY user_pseudo_id ORDER BY event_week) AS prev_week,
--     MIN(event_week) OVER(PARTITION BY user_pseudo_id) AS first_week
--   FROM base
-- ), user_classification AS (
--   SELECT
--     user_pseudo_id,
--     event_week,
--     CASE
--       WHEN event_week = first_week THEN 'New'
--       WHEN prev_week IS NOT NULL AND DATE_DIFF(event_week, prev_week, WEEK) = 1 THEN 'Current'
--       WHEN prev_week IS NOT NULL AND DATE_DIFF(event_week, prev_week, WEEK) > 1 THEN 'Resurrected'
--       ELSE 'Dormant'
--     END AS user_type
--   FROM user_activity
-- ), user_counts AS (
--   SELECT
--     event_week,
--     user_type,
--     COUNT(DISTINCT user_pseudo_id) AS user_count
--   FROM user_classification
--   GROUP BY ALL
--   ORDER BY
--     event_week,
--     user_type
-- )
-- SELECT
--   *
-- FROM user_counts

# 3) 주어진 데이터에서 어떤 사람들이 리텐션이 그나마 높을까요?
-- WITH base AS (
--   SELECT
--     DISTINCT
--       user_id,
--       DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
--       DATE_TRUNC(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul'), WEEK(MONDAY)) AS event_week,
--       user_pseudo_id
--   FROM advanced.app_logs
--   WHERE
--     event_date BETWEEN '2022-08-01' AND '2023-08-03'
-- ), user_activity AS (
--   SELECT
--     user_pseudo_id,
--     event_week,
--     LAG(event_week, 1) OVER(PARTITION BY user_pseudo_id ORDER BY event_week) AS prev_week,
--     MIN(event_week) OVER(PARTITION BY user_pseudo_id) AS first_week
--   FROM base
-- ), user_classification AS (
--   SELECT
--     user_pseudo_id,
--     event_week,
--     CASE
--       WHEN event_week = first_week THEN 'New'
--       WHEN prev_week IS NOT NULL AND DATE_DIFF(event_week, prev_week, WEEK) = 1 THEN 'Current'
--       WHEN prev_week IS NOT NULL AND DATE_DIFF(event_week, prev_week, WEEK) > 1 THEN 'Resurrected'
--       ELSE 'Dormant'
--     END AS user_type
--   FROM user_activity
-- ), user_counts AS (
--   SELECT
--     event_week,
--     user_type,
--     COUNT(DISTINCT user_pseudo_id) AS user_count
--   FROM user_classification
--   GROUP BY ALL
--   ORDER BY
--     event_week,
--     user_type
-- )
-- SELECT
--   event_week,
--   DATE_DIFF(event_week, first_week, WEEK) AS weeks_after_first_week,
--   user_type,
--   user_count,
--   cohort_users,
--   ROUND(SAFE_DIVIDE(user_count, cohort_users), 3) AS retention_rate
-- FROM (
-- SELECT
--   DATE(event_week) AS event_week,
--   DATE(MIN(event_week) OVER()) AS first_week,
--   user_type,
--   user_count,
--   MAX(CASE WHEN user_type = 'New' THEN user_count END) OVER(PARTITION BY DATE(event_week)) AS cohort_users
-- FROM user_counts
-- ORDER BY
--   event_week,
--   CASE user_type
--     WHEN 'New' THEN 1
--     WHEN 'Current' THEN 2
--     WHEN 'Resurrected' THEN 3
--     WHEN 'Dormant' THEN 4
--   END
-- )

# 4) Core Event를 'click_payment'라고 설정하고 Weekly Retention을 구해주세요
WITH base AS (
  SELECT
    DISTINCT
      user_id,
      DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
      DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul') AS event_datetime,
      user_pseudo_id
  FROM advanced.app_logs
  WHERE
    event_date BETWEEN '2022-08-01' AND '2023-08-03' AND
    event_name = 'click_payment'
), first_week_and_diff AS (
  SELECT
    *,
    DATE_DIFF(event_week, first_week, WEEK) AS diff_of_week
  FROM (
    SELECT
      DISTINCT
        user_pseudo_id,
        DATE_TRUNC(MIN(event_date) OVER(PARTITION BY user_pseudo_id), WEEK(MONDAY)) AS first_week,
        DATE_TRUNC(event_date, WEEK(MONDAY)) AS event_week
    FROM base
  )
), user_counts AS (
  SELECT
    diff_of_week,
    COUNT(DISTINCT user_pseudo_id) AS user_cnt
  FROM first_week_and_diff
  GROUP BY
    diff_of_week
  ORDER BY
    diff_of_week
)
SELECT
  diff_of_week,
  user_cnt,
  ROUND(SAFE_DIVIDE(user_cnt, cohort_users), 3) AS retention_rate
FROM (
  SELECT
    *,
    FIRST_VALUE(user_cnt) OVER(ORDER BY diff_of_week) AS cohort_users
  FROM user_counts
)
ORDER BY
  diff_of_week 



