-- 1 Basic Query, Filtering, and Aggregation
-- (Total Valid Trip)
SELECT
    COUNT(*) AS total_valid_trips
FROM gold.vw_trip_enriched;

-- (Total Trips and Average Metrics by Weekend vs. Weekday)
SELECT
    is_weekend,
    COUNT(*) AS total_trips,
    ROUND(AVG(passenger_count), 2) AS avg_passenger_count,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance,
    ROUND(AVG(total_amount), 2) AS avg_total_amount
FROM gold.vw_trip_enriched
GROUP BY is_weekend;



-- (Maximum Total Trips and Revenue by Payment Type)
SELECT
    payment_type,
    COUNT(*) AS total_trips,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_revenue,
    round(AVG(trip_distance), 2) AS avg_trip_distance
FROM gold.vw_trip_enriched
GROUP BY payment_type
ORDER BY total_trips DESC
LIMIT 1;


-- 2 Join and Location Analysis
-- (Highest Average Trip Distance by Pickup Location)
SELECT
    pickup_location,
    ROUND(SUM(avg_trip_distance * total_trips) / SUM(total_trips), 2) AS avg_trip_distance,
    SUM(total_trips) AS total_trips
FROM gold.vw_zone_performance
GROUP BY pickup_location
ORDER BY avg_trip_distance DESC
LIMIT 1;

-- (Highest Average Revenue by Pickup Location)
SELECT
    pickup_location,
    ROUND(SUM(avg_revenue * total_trips) / SUM(total_trips), 2) AS avg_revenue,
    SUM(total_trips) AS total_trips
FROM gold.vw_zone_performance
GROUP BY pickup_location
ORDER BY avg_revenue DESC
LIMIT 1;


-- 3 Date, time, and Data Quality Analysis
-- Summary of Trips by Pickup Date
SELECT
    pickup_date,
    total_trips,
    total_revenue,
    total_trip_distance,
    avg_trip_duration_minutes
FROM gold.vw_daily_trip_summary
ORDER BY pickup_date DESC;

-- Highest Invalid Data Quality Issues by error_type
SELECT
    error_type,
    COUNT(*) AS total_issues
FROM silver.data_quality_issues
GROUP BY error_type
ORDER BY total_issues DESC
LIMIT 1;


-- 4 CTE, Subquery, and Advanced Join
-- (Top 10 Pickup Locations with Highest Average Revenue)
WITH pickup_location_revenue AS (
    SELECT
        y.pulocationid,
        y.pickup_location,
        y.pickup_zone,
        ROUND(AVG(y.total_amount), 2) AS avg_revenue,
        COUNT(*) AS total_trips
    FROM gold.vw_trip_enriched y
    GROUP BY y.pulocationid, y.pickup_location, y.pickup_zone
)
SELECT *
FROM pickup_location_revenue
ORDER BY avg_revenue DESC
LIMIT 10;

-- (Highest Pickup Location with Minimum Average Tip Amount)
SELECT
    y.pickup_location,
    ROUND(AVG(y.tip_amount), 2) AS avg_tip_amount,
    COUNT(*) AS total_trips
FROM gold.vw_trip_enriched y
GROUP BY y.pickup_location
ORDER BY avg_tip_amount ASC
LIMIT 1;

-- Perbandingan revenue setiap hari terhadap rata-rata revenue harian
WITH daily_revenue AS (
    SELECT
        pickup_date,
        total_revenue
    FROM gold.vw_daily_trip_summary
),
avg_revenue AS (
    SELECT
        ROUND(AVG(total_revenue), 2) AS avg_daily_revenue
    FROM daily_revenue
)
SELECT
    dr.pickup_date,
    dr.total_revenue,
    ar.avg_daily_revenue,
    ROUND(dr.total_revenue - ar.avg_daily_revenue, 2) AS revenue_difference
FROM daily_revenue dr
CROSS JOIN avg_revenue ar
ORDER BY dr.total_revenue DESC;


-- 5 Ranking and Window Functions
-- Pickup Locations Ranked by Total Revenue
SELECT
    pickup_location,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    SUM(total_trips) AS total_trips,
    RANK() OVER (ORDER BY SUM(total_revenue) DESC) AS revenue_rank
FROM gold.vw_zone_performance
GROUP BY pickup_location
ORDER BY revenue_rank;

-- Pickup Locations Ranked by Borough
SELECT
    pickup_location AS borough,
    pickup_zone,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    COUNT(*) AS total_trips,
    RANK() OVER (PARTITION BY pickup_location ORDER BY SUM(total_amount) DESC) AS revenue_rank_within_borough
FROM gold.vw_trip_enriched
GROUP BY pickup_location, pickup_zone
ORDER BY pickup_location, revenue_rank_within_borough;

-- Moving Average by Trip Duration (7-day Moving Average)
WITH daily_trip_duration AS (
    SELECT
        pickup_date,
        avg_trip_duration_minutes AS avg_trip_duration
    FROM gold.vw_daily_trip_summary
)
SELECT
    pickup_date,
    avg_trip_duration,
    ROUND(AVG(avg_trip_duration) OVER (ORDER BY pickup_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_trip_duration_7_days
FROM daily_trip_duration
ORDER BY pickup_date;
