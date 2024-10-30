# 퍼널 데이터 (틀림)
-- SELECT
--   event_date,
--   CONCAT(param.key, '-', param.value.string_value) AS event_name_with_screen,
--   CASE
--     WHEN CONCAT(param.key, '-', param.value.string_value) LIKE '%welcome%' THEN 1
--     WHEN CONCAT(param.key, '-', param.value.string_value) LIKE '%home%' THEN 2
--     WHEN CONCAT(param.key, '-', param.value.string_value) LIKE '%food_category%' THEN 3
--     WHEN CONCAT(param.key, '-', param.value.string_value) LIKE '%restaurant%' THEN 4
--     WHEN CONCAT(param.key, '-', param.value.string_value) LIKE '%screen_view-cart%' THEN 5
--     WHEN CONCAT(param.key, '-', param.value.string_value) LIKE '%click_payment-cart%' THEN 6
--   END AS step_number,
--   COUNT(user_pseudo_id) AS cnt
-- FROM advanced.app_logs
-- CROSS JOIN UNNEST(event_params) AS param
-- WHERE
--   event_date = '2022-08-01' AND
--   event_name IN ('screen_view', 'click_payment')
-- GROUP BY ALL
-- LIMIT 100


-- 퍼널 데이터
-- 우리가 사용할 이벤트 => 단계
-- screen_view : welcome. home, food_category, restaurant, cart
-- click_payment
-- step_number : 추후에 정렬을 위해 만들 것
-- 사용할 데이터 : 앱 로그 데이터. GA/Firebase => UNNEST => PIVOT
-- 기간 : 2022-08-01 ~ 2022-08-18
WITH base AS (
  SELECT
    event_date,
    event_timestamp,
    event_name,
    user_id,
    user_pseudo_id,
    platform,
    MAX(IF(event_param.key = 'firebase_screen', event_param.value.string_value, NULL)) AS firebase_screen,
    #MAX(IF(event_param.key = 'food_id', event_param.value.int_value, NULL)) AS food_id,
    MAX(IF(event_param.key = 'session_id', event_param.value.string_value, NULL)) AS session_id,
  FROM advanced.app_logs
  CROSS JOIN UNNEST(event_params) AS event_param
  WHERE
    event_date BETWEEN '2022-08-01' AND '2022-08-18'
  GROUP BY ALL
), filter_event_and_concat_event_and_screen AS (
  -- event_name + screen (필요한 이벤트만 WHERE 조건에 걸어서 사용)
  SELECT
    * EXCEPT(event_name, firebase_screen, event_timestamp),
    CONCAT(event_name, '-', firebase_screen) AS event_name_with_screen,
    DATETIME(TIMESTAMP_MICROS(event_timestamp), 'Asia/Seoul') AS event_datetime
  FROM base
  WHERE
    event_name IN ('screen_view', 'click_payment')
), before_pivot AS (
  -- step_number + COUNT
  -- step_number : CASE WHEN을 사용해 숫자 지정
  # 일자 상관없이 퍼널의 유저 수를 집계한 쿼리 => 일자별로 하기 위해 event_date 추가
  SELECT
    event_date, # 일자별로 퍼널별 유저 수 쿼리
    event_name_with_screen,
    CASE
      WHEN event_name_with_screen = 'screen_view-welcome' THEN 1
      WHEN event_name_with_screen = 'screen_view-home' THEN 2
      WHEN event_name_with_screen = 'screen_view-food_category' THEN 3
      WHEN event_name_with_screen = 'screen_view-restaurant' THEN 4
      WHEN event_name_with_screen = 'screen_view-cart' THEN 5
      WHEN event_name_with_screen = 'click_payment-cart' THEN 6
    ELSE NULL
    END AS step_number,
    COUNT(DISTINCT user_pseudo_id) AS cnt
  FROM filter_event_and_concat_event_and_screen
  GROUP BY ALL
  HAVING
    step_number IS NOT NULL
  ORDER BY
    event_date
  -- food_detail, search, search_result도 보면서 어떤 흐름으로 고객이 움직이는지 확인해보기
)
-- SELECT
--   *
-- FROM before_pivot

# 집계한 데이터를 PIVOT. PIVOT 한 형태에서 퍼널 별 전환율을 쉽게 구할 수 있음
-- SELECT
--   event_date,
--   MAX(IF(event_name_with_screen = 'screen_view-welcome', cnt, NULL)) AS `screen_view-welcome`, #1
--   MAX(IF(event_name_with_screen = 'screen_view-home', cnt, NULL)) AS `screen_view-home`, #2
--   MAX(IF(event_name_with_screen = 'screen_view-food_category', cnt, NULL)) AS `screen_view-food_category`, #3
--   MAX(IF(event_name_with_screen = 'screen_view-restaurant', cnt, NULL)) AS `screen_view-restaurant`, #4
--   MAX(IF(event_name_with_screen = 'screen_view-cart', cnt, NULL)) AS `screen_view-cart`, #5
--   MAX(IF(event_name_with_screen = 'click_payment-cart', cnt, NULL)) AS `click_payment-cart`, #6
--   CAST(MAX(IF(event_name_with_screen = 'screen_view-home', cnt, NULL)) AS FLOAT64) / CAST(MAX(IF(event_name_with_screen = 'screen_view-welcome', cnt, NULL)) AS FLOAT64) AS CVR1, # 2 / 1
--   CAST(MAX(IF(event_name_with_screen = 'screen_view-food_category', cnt, NULL)) AS FLOAT64) / CAST(MAX(IF(event_name_with_screen = 'screen_view-home', cnt, NULL)) AS FLOAT64) AS CVR2, # 3 / 2 
--   CAST(MAX(IF(event_name_with_screen = 'screen_view-restaurant', cnt, NULL)) AS FLOAT64) / CAST(MAX(IF(event_name_with_screen = 'screen_view-food_category', cnt, NULL)) AS FLOAT64) AS CVR3, # 4 / 3
--   CAST(MAX(IF(event_name_with_screen = 'screen_view-cart', cnt, NULL)) AS FLOAT64) / CAST(MAX(IF(event_name_with_screen = 'screen_view-restaurant', cnt, NULL)) AS FLOAT64) AS CVR4, # 5 / 4
--   CAST(MAX(IF(event_name_with_screen = 'click_payment-cart', cnt, NULL)) AS FLOAT64) / CAST(MAX(IF(event_name_with_screen = 'screen_view-cart', cnt, NULL)) AS FLOAT64) AS CVR5 # 6 / 5
-- FROM before_pivot
-- GROUP BY ALL
-- ORDER BY
--   event_date
-- LIMIT 10


SELECT
  *
FROM before_pivot




