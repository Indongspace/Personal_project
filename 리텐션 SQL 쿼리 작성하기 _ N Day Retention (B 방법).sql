# B 방법 : 짧고 간결한 형태
-- first_date를 구하면서 바로 event_date를 구성하는 형태
WITH base AS (
  SELECT
    -- 그냥 가져오면 중복이 생길 수 있음
    DISTINCT # event_timestamp 기반으로 중복을 처
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
), first_date_and_diff AS (
  SELECT
    *,
    DATE_DIFF(event_date, first_date, DAY) AS diff_of_day
  FROM (
    SELECT
    # 일자별로 중복 제거
      DISTINCT
        user_pseudo_id,
        MIN(event_date) OVER(PARTITION BY user_pseudo_id) AS first_date,
        event_date
    FROM base
  )
)

SELECT
  diff_of_day,
  COUNT(DISTINCT user_pseudo_id) AS user_cnt
FROM first_date_and_diff
GROUP BY
  diff_of_day
ORDER BY
  diff_of_day

# B 방법이 더 짧고, 직관적이긴 하나 A 방법이 더 세분화적인 조건을 설정할 수 있을 것

# N Day Retention => Weekly Retention



