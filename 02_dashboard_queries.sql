-- ============================================================
-- 제로편도 대시보드 수치 산출 쿼리 모음
-- 작성일: 2026-04-03
-- 작성자: emma + claude
-- 필터 기준: date >= '2025-01-01' AND date < '2026-01-01'
--            state = 3, member_imaginary IN (0, 9)
--            way IN ('z2d_oneway', 'd2d_oneway')
--            제주 제외 (cz.region1 != '제주특별자치도')
-- 조인키: 전부 reservation_id
-- ============================================================


-- ============================================================
-- Q1. 전국 편도 총건수 + 탁송비 총액 (제주 제외)
-- 결과: 377,506건, 60.6억
-- ============================================================
SELECT
  COUNT(*) AS cnt,
  ROUND(SUM(
    COALESCE(r.transport_cost_socar,0)
    + COALESCE(r.transport_cost_d2d,0)
    + COALESCE(r.transport_cost_z2d,0)
    + COALESCE(r.transport_cost_mobility,0)
  )) AS total_transport
FROM `socar-data.soda_store.reservation_v2` r
LEFT JOIN `socar-data.tianjin_replica.carzone_info` cz ON r.zone_id = cz.id
WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
  AND r.state = 3
  AND r.member_imaginary IN (0, 9)
  AND r.way IN ('z2d_oneway','d2d_oneway')
  AND cz.region1 != '제주특별자치도';


-- ============================================================
-- Q2. 전국 크로스 구간(타시도 반납) 건수
-- 결과: 91,428건
-- ============================================================
SELECT
  COUNT(*) AS cross_region_cnt
FROM `socar-data.soda_store.reservation_v2` r
JOIN `socar-data.tianjin_replica.reservation_dtod_info` d ON r.reservation_id = d.reservation_id
LEFT JOIN `socar-data.tianjin_replica.carzone_info` cz ON r.zone_id = cz.id
WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
  AND r.state = 3
  AND r.member_imaginary IN (0, 9)
  AND r.way IN ('z2d_oneway','d2d_oneway')
  AND cz.region1 != '제주특별자치도'
  AND cz.region1 != CASE
    WHEN d.end_address1 LIKE '서울%' THEN '서울특별시'
    WHEN d.end_address1 LIKE '경기%' THEN '경기도'
    WHEN d.end_address1 LIKE '인천%' THEN '인천광역시'
    WHEN d.end_address1 LIKE '대전%' THEN '대전광역시'
    WHEN d.end_address1 LIKE '세종%' THEN '세종특별자치시'
    WHEN d.end_address1 LIKE '충남%' OR d.end_address1 LIKE '충청남도%' THEN '충청남도'
    WHEN d.end_address1 LIKE '충북%' OR d.end_address1 LIKE '충청북도%' THEN '충청북도'
    WHEN d.end_address1 LIKE '부산%' THEN '부산광역시'
    WHEN d.end_address1 LIKE '울산%' THEN '울산광역시'
    WHEN d.end_address1 LIKE '대구%' THEN '대구광역시'
    WHEN d.end_address1 LIKE '광주%' THEN '광주광역시'
    WHEN d.end_address1 LIKE '경남%' OR d.end_address1 LIKE '경상남도%' THEN '경상남도'
    WHEN d.end_address1 LIKE '경북%' OR d.end_address1 LIKE '경상북도%' THEN '경상북도'
    WHEN d.end_address1 LIKE '전남%' OR d.end_address1 LIKE '전라남도%' THEN '전라남도'
    WHEN d.end_address1 LIKE '전북%' OR d.end_address1 LIKE '전라북도%' OR d.end_address1 LIKE '전북특별자치도%' THEN '전라북도'
    WHEN d.end_address1 LIKE '강원%' OR d.end_address1 LIKE '강원특별자치도%' THEN '강원도'
    WHEN d.end_address1 LIKE '제주%' THEN '제주특별자치도'
    ELSE 'other'
  END;


-- ============================================================
-- Q3. 전국 양방향 매칭 TOP30 + KPI 총합
-- 결과: 38,765쌍, 탁송비절감 12.3억(100%), 추가GP 9.5억(100%)
-- 50% 기준: 탁송비절감 6.1억, 추가매출 16.8억, 추가GP 4.8억, 총GP 10.9억
-- ============================================================
WITH raw AS (
  SELECT
    r.reservation_id,
    cz.region1 AS start_region,
    CASE
      WHEN d.end_address1 LIKE '서울%' THEN '서울특별시'
      WHEN d.end_address1 LIKE '경기%' THEN '경기도'
      WHEN d.end_address1 LIKE '인천%' THEN '인천광역시'
      WHEN d.end_address1 LIKE '대전%' THEN '대전광역시'
      WHEN d.end_address1 LIKE '세종%' THEN '세종특별자치시'
      WHEN d.end_address1 LIKE '충남%' OR d.end_address1 LIKE '충청남도%' THEN '충청남도'
      WHEN d.end_address1 LIKE '충북%' OR d.end_address1 LIKE '충청북도%' THEN '충청북도'
      WHEN d.end_address1 LIKE '부산%' THEN '부산광역시'
      WHEN d.end_address1 LIKE '울산%' THEN '울산광역시'
      WHEN d.end_address1 LIKE '대구%' THEN '대구광역시'
      WHEN d.end_address1 LIKE '광주%' THEN '광주광역시'
      WHEN d.end_address1 LIKE '경남%' OR d.end_address1 LIKE '경상남도%' THEN '경상남도'
      WHEN d.end_address1 LIKE '경북%' OR d.end_address1 LIKE '경상북도%' THEN '경상북도'
      WHEN d.end_address1 LIKE '전남%' OR d.end_address1 LIKE '전라남도%' THEN '전라남도'
      WHEN d.end_address1 LIKE '전북%' OR d.end_address1 LIKE '전라북도%' OR d.end_address1 LIKE '전북특별자치도%' THEN '전라북도'
      WHEN d.end_address1 LIKE '강원%' OR d.end_address1 LIKE '강원특별자치도%' THEN '강원도'
      WHEN d.end_address1 LIKE '제주%' THEN '제주특별자치도'
      ELSE 'other'
    END AS end_region,
    COALESCE(r.transport_cost_socar,0)+COALESCE(r.transport_cost_d2d,0)+COALESCE(r.transport_cost_z2d,0)+COALESCE(r.transport_cost_mobility,0) AS transport_cost,
    COALESCE(r._rev_rent,0)+COALESCE(r._rev_oil,0) AS core_rev,
    p.profit AS gp
  FROM `socar-data.soda_store.reservation_v2` r
  JOIN `socar-data.tianjin_replica.reservation_dtod_info` d ON r.reservation_id = d.reservation_id
  LEFT JOIN `socar-data.tianjin_replica.carzone_info` cz ON r.zone_id = cz.id
  LEFT JOIN `socar-data.socar_biz_profit.profit_socar_reservation` p ON r.reservation_id = p.reservation_id
  WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
    AND r.state = 3
    AND r.member_imaginary IN (0, 9)
    AND r.way IN ('z2d_oneway','d2d_oneway')
    AND cz.region1 != '제주특별자치도'
),
cross_region AS (
  SELECT * FROM raw
  WHERE start_region != end_region
    AND end_region != 'other'
    AND end_region != '제주특별자치도'
),
agg AS (
  SELECT
    start_region, end_region,
    COUNT(*) AS cnt,
    APPROX_QUANTILES(transport_cost, 100)[OFFSET(50)] AS med_transport,
    AVG(transport_cost) AS avg_transport,
    AVG(core_rev) AS avg_rev,
    AVG(gp) AS avg_gp
  FROM cross_region
  GROUP BY 1, 2
),
pairs AS (
  SELECT
    a.start_region AS region_a,
    a.end_region AS region_b,
    a.cnt AS a_to_b,
    b.cnt AS b_to_a,
    LEAST(a.cnt, b.cnt) AS match_pairs,
    a.med_transport + b.med_transport - 20000 AS pair_transport_saving,
    (a.avg_rev + b.avg_rev) / 2.0 AS pair_avg_rev,
    (a.avg_gp + b.avg_gp) / 2.0 AS pair_avg_gp
  FROM agg a
  JOIN agg b ON a.start_region = b.end_region AND a.end_region = b.start_region
  WHERE a.start_region < a.end_region
)
SELECT
  region_a, region_b, a_to_b, b_to_a, match_pairs,
  ROUND(pair_transport_saving) AS pair_transport_saving,
  ROUND(pair_avg_rev) AS pair_avg_rev,
  ROUND(pair_avg_gp) AS pair_avg_gp,
  ROUND(match_pairs * pair_transport_saving) AS total_transport_saving,
  ROUND(match_pairs * pair_avg_rev) AS total_rev,
  ROUND(match_pairs * pair_avg_gp) AS total_gp
FROM pairs
ORDER BY match_pairs DESC
LIMIT 30;


-- ============================================================
-- Q4. 충청 편도 총건수 + 탁송비 (시도별)
-- 결과: 23,794건, 4.12억
-- ============================================================
SELECT
  cz.region1 AS start_region,
  COUNT(*) AS cnt,
  ROUND(SUM(
    COALESCE(r.transport_cost_socar,0)
    + COALESCE(r.transport_cost_d2d,0)
    + COALESCE(r.transport_cost_z2d,0)
    + COALESCE(r.transport_cost_mobility,0)
  )) AS total_transport
FROM `socar-data.soda_store.reservation_v2` r
LEFT JOIN `socar-data.tianjin_replica.carzone_info` cz ON r.zone_id = cz.id
WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
  AND r.state = 3
  AND r.member_imaginary IN (0, 9)
  AND r.way IN ('z2d_oneway','d2d_oneway')
  AND cz.region1 IN ('대전광역시','세종특별자치시','충청남도','충청북도')
GROUP BY cz.region1
ORDER BY cnt DESC;


-- ============================================================
-- Q5. 충청 양방향 매칭 (6개 크로스 구간)
-- 결과: 1,458쌍, 총GP개선 3,264만(50%)
-- ============================================================
WITH oneway AS (
  SELECT
    r.reservation_id,
    cz.region1 AS start_region,
    CASE
      WHEN d.end_address1 LIKE '대전%' THEN '대전광역시'
      WHEN d.end_address1 LIKE '세종%' THEN '세종특별자치시'
      WHEN d.end_address1 LIKE '충남%' OR d.end_address1 LIKE '충청남도%' THEN '충청남도'
      WHEN d.end_address1 LIKE '충북%' OR d.end_address1 LIKE '충청북도%' THEN '충청북도'
      ELSE 'other'
    END AS end_region,
    COALESCE(r.transport_cost_socar,0)+COALESCE(r.transport_cost_d2d,0)+COALESCE(r.transport_cost_z2d,0)+COALESCE(r.transport_cost_mobility,0) AS transport_cost,
    COALESCE(r._rev_rent,0)+COALESCE(r._rev_oil,0) AS core_rev,
    p.profit AS gp
  FROM `socar-data.soda_store.reservation_v2` r
  JOIN `socar-data.tianjin_replica.reservation_dtod_info` d ON r.reservation_id = d.reservation_id
  LEFT JOIN `socar-data.tianjin_replica.carzone_info` cz ON r.zone_id = cz.id
  LEFT JOIN `socar-data.socar_biz_profit.profit_socar_reservation` p ON r.reservation_id = p.reservation_id
  WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
    AND r.state = 3
    AND r.member_imaginary IN (0, 9)
    AND r.way IN ('z2d_oneway','d2d_oneway')
    AND cz.region1 IN ('대전광역시','세종특별자치시','충청남도','충청북도')
),
cross_region AS (
  SELECT * FROM oneway
  WHERE end_region IN ('대전광역시','세종특별자치시','충청남도','충청북도')
    AND start_region != end_region
),
agg AS (
  SELECT
    start_region, end_region,
    COUNT(*) AS cnt,
    APPROX_QUANTILES(transport_cost, 100)[OFFSET(50)] AS med_transport,
    AVG(transport_cost) AS avg_transport,
    AVG(core_rev) AS avg_rev,
    AVG(gp) AS avg_gp
  FROM cross_region
  GROUP BY 1, 2
),
pairs AS (
  SELECT
    a.start_region AS region_a,
    a.end_region AS region_b,
    a.cnt AS a_to_b,
    b.cnt AS b_to_a,
    LEAST(a.cnt, b.cnt) AS match_pairs,
    a.med_transport + b.med_transport - 20000 AS pair_transport_saving,
    (a.avg_rev + b.avg_rev) / 2.0 AS pair_avg_rev,
    (a.avg_gp + b.avg_gp) / 2.0 AS pair_avg_gp
  FROM agg a
  JOIN agg b ON a.start_region = b.end_region AND a.end_region = b.start_region
  WHERE a.start_region < a.end_region
)
SELECT
  region_a, region_b, a_to_b, b_to_a, match_pairs,
  ROUND(pair_transport_saving) AS pair_transport_saving,
  ROUND(pair_avg_rev) AS pair_avg_rev,
  ROUND(pair_avg_gp) AS pair_avg_gp,
  ROUND(match_pairs * pair_transport_saving) AS total_transport_saving,
  ROUND(match_pairs * pair_avg_rev) AS total_rev,
  ROUND(match_pairs * pair_avg_gp) AS total_gp
FROM pairs
ORDER BY match_pairs DESC;

-- 충청 KPI 총합 (위 쿼리 마지막에 추가)
-- SELECT
--   SUM(match_pairs) AS total_pairs,
--   SUM(match_pairs) * 2 AS total_individual_trips,
--   ROUND(SUM(match_pairs * pair_transport_saving) * 0.5) AS transport_saving_50pct,
--   ROUND(SUM(match_pairs * pair_avg_rev) * 0.5) AS rev_50pct,
--   ROUND(SUM(match_pairs * pair_avg_gp) * 0.5) AS gp_50pct,
--   ROUND(SUM(match_pairs * (pair_transport_saving + pair_avg_gp)) * 0.5) AS total_gp_improvement_50pct
-- FROM pairs;


-- ============================================================
-- Q6. 편도 주차비 (건당 평균)
-- 결과: 건당 평균 1,668원, 중위 1,843원, 연간 총 6.3억
-- parking_cost_oneway는 전부 0, d2d + z2d만 유효
-- ============================================================
SELECT
  COUNT(*) AS cnt,
  ROUND(AVG(COALESCE(parking_cost_d2d,0) + COALESCE(parking_cost_z2d,0))) AS avg_parking,
  APPROX_QUANTILES(COALESCE(parking_cost_d2d,0) + COALESCE(parking_cost_z2d,0), 100)[OFFSET(50)] AS med_parking,
  ROUND(SUM(COALESCE(parking_cost_d2d,0) + COALESCE(parking_cost_z2d,0))) AS total_parking
FROM `socar-data.soda_store.reservation_v2` r
LEFT JOIN `socar-data.tianjin_replica.carzone_info` cz ON r.zone_id = cz.id
WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
  AND r.state = 3
  AND r.member_imaginary IN (0, 9)
  AND r.way IN ('z2d_oneway','d2d_oneway')
  AND cz.region1 != '제주특별자치도';


-- ============================================================
-- Q7. 지역 내 재배치 비용 (같은 시도 내 편도 탁송비 중위값)
-- 결과: 대전 9,825 / 세종 9,839 / 충남 10,412 / 충북 11,197
--        서울 10,977 / 경기 13,015 / 부산 10,708
-- ============================================================
WITH oneway AS (
  SELECT
    cz.region1 AS start_region,
    CASE
      WHEN d.end_address1 LIKE '서울%' THEN '서울특별시'
      WHEN d.end_address1 LIKE '경기%' THEN '경기도'
      WHEN d.end_address1 LIKE '인천%' THEN '인천광역시'
      WHEN d.end_address1 LIKE '대전%' THEN '대전광역시'
      WHEN d.end_address1 LIKE '세종%' THEN '세종특별자치시'
      WHEN d.end_address1 LIKE '충남%' OR d.end_address1 LIKE '충청남도%' THEN '충청남도'
      WHEN d.end_address1 LIKE '충북%' OR d.end_address1 LIKE '충청북도%' THEN '충청북도'
      WHEN d.end_address1 LIKE '부산%' THEN '부산광역시'
      ELSE 'other'
    END AS end_region,
    COALESCE(r.transport_cost_socar,0)+COALESCE(r.transport_cost_d2d,0)+COALESCE(r.transport_cost_z2d,0)+COALESCE(r.transport_cost_mobility,0) AS transport_cost
  FROM `socar-data.soda_store.reservation_v2` r
  JOIN `socar-data.tianjin_replica.reservation_dtod_info` d ON r.reservation_id = d.reservation_id
  LEFT JOIN `socar-data.tianjin_replica.carzone_info` cz ON r.zone_id = cz.id
  WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
    AND r.state = 3
    AND r.member_imaginary IN (0, 9)
    AND r.way IN ('z2d_oneway','d2d_oneway')
)
SELECT
  start_region,
  COUNT(*) AS cnt,
  APPROX_QUANTILES(transport_cost, 100)[OFFSET(50)] AS med_transport
FROM oneway
WHERE start_region = end_region
GROUP BY start_region
ORDER BY cnt DESC;


-- ============================================================
-- Q8. 편도 반납 후 유휴시간 분포
-- 결과: 평균 24.8시간, 중위 17시간
-- 24시간 이상 31.3%, 48시간 이상 10.9%
-- ============================================================
WITH oneway AS (
  SELECT
    r.reservation_id,
    r.car_id,
    r.return_at_kst,
    LEAD(r.start_at_kst) OVER (PARTITION BY r.car_id ORDER BY r.start_at_kst) AS next_start
  FROM `socar-data.soda_store.reservation_v2` r
  LEFT JOIN `socar-data.tianjin_replica.carzone_info` cz ON r.zone_id = cz.id
  WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
    AND r.state = 3
    AND r.member_imaginary IN (0, 9)
    AND r.way IN ('z2d_oneway','d2d_oneway')
    AND cz.region1 != '제주특별자치도'
),
idle AS (
  SELECT
    reservation_id,
    TIMESTAMP_DIFF(next_start, return_at_kst, HOUR) AS idle_hours
  FROM oneway
  WHERE next_start IS NOT NULL
    AND TIMESTAMP_DIFF(next_start, return_at_kst, HOUR) BETWEEN 0 AND 336
)
SELECT
  COUNT(*) AS cnt,
  ROUND(AVG(idle_hours), 1) AS avg_idle_hours,
  APPROX_QUANTILES(idle_hours, 100)[OFFSET(50)] AS med_idle_hours,
  ROUND(COUNTIF(idle_hours >= 24) / COUNT(*) * 100, 1) AS pct_over_24h,
  ROUND(COUNTIF(idle_hours >= 48) / COUNT(*) * 100, 1) AS pct_over_48h
FROM idle;


-- ============================================================
-- Q9. 차량 일평균 GP (기회비용 산출용)
-- 결과: 7,854원/일
-- ============================================================
SELECT
  ROUND(AVG(daily_gp)) AS avg_daily_gp
FROM (
  SELECT
    r.car_id,
    DATE(r.date) AS dt,
    SUM(p.profit) AS daily_gp
  FROM `socar-data.soda_store.reservation_v2` r
  LEFT JOIN `socar-data.socar_biz_profit.profit_socar_reservation` p ON r.reservation_id = p.reservation_id
  WHERE r.date >= '2025-01-01' AND r.date < '2026-01-01'
    AND r.state = 3
    AND r.member_imaginary IN (0, 9)
  GROUP BY r.car_id, DATE(r.date)
);


-- ============================================================
-- 대시보드 핵심 수치 요약
-- ============================================================
-- 전국 (제주 제외)
--   총 편도: 377,506건, 탁송비 60.6억
--   크로스 구간: 91,428건
--   양방향 매칭: 38,765쌍 → 50% = 38,766건(개별)
--   탁송비 절감: 6.1억 (건당 15,849원)
--   추가 매출: 16.8억 (건당 43,232원)
--   추가 GP: 4.8억 (건당 12,275원)
--   총 GP 개선: 10.9억 (건당 28,124원)
--
-- 충청
--   총 편도: 23,794건, 탁송비 4.12억
--   크로스 구간: 3,103건
--   양방향 매칭: 1,458쌍 → 50% = 1,458건(개별)
--   탁송비 절감: 1,946만 (건당 13,348원)
--   추가 매출: 4,360만 (건당 29,906원)
--   추가 GP: 1,318만 (건당 9,042원)
--   총 GP 개선: 3,264만 (건당 22,388원)
--
-- 건당 경제성 (AS-IS)
--   탁송비: 16,087원, 주차비: 1,668원, 기회비용: 7,854원 = 총 25,607원
--   24h 대기 비용: 9,520원 (주차 1,668 + 기회비용 7,854)
--   매칭 시 GP 개선: 28,124원 → ROI 3.0배
