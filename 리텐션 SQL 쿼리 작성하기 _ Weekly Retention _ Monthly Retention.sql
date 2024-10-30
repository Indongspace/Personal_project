-- Weekly 리텐션
-- 핵심 : event_date => event_week으로 변경하면 됨
-- 2024-06-30(일) => 2024년 26주차. 2024-06-24(월)도 같은 26주차
-- 데이터를 전처리(가공)하기 위해서 WEEK 함수를 사용할 수도 있고, DATE_TRUNC(일자, 자를 기준)
  -- DATE_TRUNC : 2024-06-30 => 2024-06-24
  -- WEEK : 26. 2024년 26주차. 주차 별 date를 직관적으로 알기 어렵다
  -- WEEK vs ISO_WEEK
  -- 주 번호를 계산할 때 사용할 수 있는 함수
  -- WEEK : 일요일이 주의 첫 날로 간주. 1월1일이 속한 주가 1주차
  -- ISO_WEEK : 월요일이 주의 첫 날로 간주. ISO 8601 국제 표준에 따라 정의. 목요일이 속한 주를 기준으로 주 번호를 지정(목요일이 속하면 그 주의 4일 이상이 포함되기 때문, 연도의 첫 목요일이 있는 주부터 1주차)
  -- 2022년 1월 1일(토요일) WEEK : 2022년 1주차. ISO_WEEK 2021년 52주차
  -- 첫 목요일은 2022-01-06. 2022-01-03 ~ 2022-01-09가 2022년 1주차

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
--     event_date BETWEEN '2022-08-01' AND '2022-11-03'
-- ), first_week_and_diff AS (
--   SELECT
--     *,
--     # DATE_DIFF(event_date, first_date, DAY) AS diff_of_day
--     DATE_DIFF(event_week, first_week, WEEK) AS diff_of_week
--   FROM (
--     SELECT
--       DISTINCT
--         -- DATE_TRUNC
--         user_pseudo_id,
--         DATE_TRUNC(MIN(event_date) OVER(PARTITION BY user_pseudo_id), WEEK(MONDAY)) AS first_week,
--         DATE_TRUNC(event_date, WEEK(MONDAY)) AS event_week,
--         -- event_date
--     FROM base
--   )
-- ), user_counts AS (
--   SELECT
--     diff_of_week,
--     COUNT(DISTINCT user_pseudo_id) AS user_cnt
--   FROM first_week_and_diff
--   GROUP BY
--     diff_of_week
-- )

-- SELECT
--   *,
--   ROUND(SAFE_DIVIDE(user_cnt, first_cnt), 3) AS retention_rate
-- FROM (
--   SELECT
--     *,
--     FIRST_VALUE(user_cnt) OVER(ORDER BY diff_of_week) AS first_cnt
--   FROM user_counts
-- )
-- ORDER BY
--   diff_of_week

# Monthly 리텐션 쿼리 작성해보기
WITH base AS (
  SELECT
    DISTINCT
      user_id,
      event_name,
      DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
      DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul') AS event_datetime,
      user_pseudo_id
  FROM advanced.app_logs
  WHERE
    event_date BETWEEN '2022-08-01' AND '2022-11-03'
), first_month_and_diff AS (
  SELECT
    *,
    # DATE_DIFF(event_date, first_date, DAY) AS diff_of_day
    # DATE_DIFF(event_week, first_week, WEEK) AS diff_of_week,
    DATE_DIFF(event_month, first_month, MONTH) AS diff_of_month
  FROM (
    SELECT
      DISTINCT
        -- DATE_TRUNC
        user_pseudo_id,
        DATE_TRUNC(MIN(event_date) OVER(PARTITION BY user_pseudo_id), MONTH) AS first_month,
        DATE_TRUNC(event_date, MONTH) AS event_month,
        -- event_date
    FROM base
  )
)
SELECT
  diff_of_month,
  COUNT(DISTINCT user_pseudo_id) AS user_cnt
FROM first_month_and_diff
GROUP BY
  diff_of_month
ORDER BY
  diff_of_month
  
