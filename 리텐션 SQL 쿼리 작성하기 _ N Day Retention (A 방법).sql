# N Day Retention
# Core : 앱 접속 
# 중간 Table : user_pseudo_id | first_date | event_date | diff_of_day
  # 중간 Table을 만들기 위한 Table
  -- user_pseudo_id | first_date : 유저마다 첫 접속일을 알기 위한 데이터
  -- user_pseudo_id | event_date : 유저가 이벤트를 발생시킨 일자를 알기 위한 데이터
  -- 위의 두 Table을 JOIN(Key : user_pseudo_id)
# 결과 Table : diff_of_day | user_cnt
-- 일자 : 2022-08-01 ~ 2022-11-03
# 2가지 방법으로 쿼리를 작성(3가지) A(1, 2), B
WITH base AS (
  SELECT
    -- 그냥 가져오면 중복이 생길 수 있음
    DISTINCT
      user_id,
      -- event_date, # Firebase의 형태와 살짝 다름. event_date : 20220813
      event_name,
      DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul') AS event_datetime,
      DATE(DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul')) AS event_date,
      user_pseudo_id
  FROM advanced.app_logs
  WHERE
    event_date BETWEEN '2022-08-01' AND '2022-11-03'
  -- 리텐션 데이터 : 전체 데이터 스캔해야 할 수도 있음(앱 로그 전체를 알아야 하기 때문)
), first_data AS (
# 첫 접속일을 구하기 위한 데이터
  SELECT
    user_pseudo_id,
    # 2022-01-01, 2024-06-20 => 첫 접속일은 제일 작은 값. MIN 값을 활용해 추출
    MIN(event_date) AS first_date
  FROM base
  GROUP BY
    user_pseudo_id
), event_data AS (
  SELECT
    user_pseudo_id,
    event_date
  FROM base
  GROUP BY ALL
), retain_base AS (
-- first_data + event_data JOIN
  SELECT
    fd.user_pseudo_id,
    fd.first_date,
    ed.event_date,
    DATE_DIFF(ed.event_date, fd.first_date, DAY) AS diff_of_day
  FROM first_data AS fd
  LEFT JOIN event_data AS ed
  ON fd.user_pseudo_id = ed.user_pseudo_id
), user_counts AS (
  -- 이 데이터를 사용해서 리텐션 커브를 구할 때, 구글 시트 등에서 별도의 작업을 진행 
  -- 쿼리로 다 진행하고 싶다. 모든 컬럼에 35803을 추가하고 싶다(diff_of_day가 0인 user_cnt)
    -- A-1 : 쿼리문을 만들고 JOIN하는 방법
    -- A-2 : 윈도우 함수를 사용하는 방법
  SELECT
    diff_of_day,
    COUNT(DISTINCT user_pseudo_id) AS user_cnt
  FROM retain_base
  GROUP BY
    diff_of_day
), first_day_user_count AS (
  -- first_day_user_count = diff_of_day가 0인 user_cnt
  SELECT
    user_cnt AS first_day_user_cnt
  FROM user_counts
  WHERE
    diff_of_day = 0
  -- JOIN을 할 때 모든 값에 곱하고 싶을 때 => CROSS JOIN
)

-- -- A-1번
-- SELECT
--   uc.diff_of_day,
--   uc.user_cnt,
--   fduc.first_day_user_cnt,
--   ROUND(SAFE_DIVIDE(uc.user_cnt, fduc.first_day_user_cnt), 3) AS retention_rate
-- FROM user_counts AS uc
-- CROSS JOIN first_day_user_count AS fduc
-- ORDER BY
--   uc.diff_of_day


-- -- A-2번 : 윈도우 함수를 사용한 방법
-- SELECT
--   *,
--   ROUND(SAFE_DIVIDE(user_cnt, first_day_user_cnt), 3) AS retention_rate
-- FROM (
--   SELECT
--     diff_of_day,
--     user_cnt,
--     FIRST_VALUE(user_cnt) OVER(ORDER BY diff_of_day) AS first_day_user_cnt
--   FROM user_counts
-- )









