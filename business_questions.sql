-- 1 Basic Query, Filtering, and Aggregation
-- (Total Valid Trip)
SELECT
    COUNT(*) AS total_valid_trips
FROM silver.cleaned_yellow_taxi_trip;

-- (Total Trips and Average Metrics by Weekend vs. Weekday)
SELECT
    is_weekend,
    COUNT(*) AS total_trips,
    ROUND(AVG(passenger_count), 2) AS avg_passenger_count,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance,
    ROUND(AVG(total_amount), 2) AS avg_total_amount
FROM silver.cleaned_yellow_taxi_trip
GROUP BY is_weekend;



-- (Maximum Total Trips and Revenue by Payment Type)
SELECT
    payment_type,
    COUNT(*) AS total_trips,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_revenue,
    round(AVG(trip_distance), 2) AS avg_trip_distance
FROM silver.cleaned_yellow_taxi_trip
GROUP BY payment_type
ORDER BY total_trips DESC
LIMIT 1;


-- 2 Join and Location Analysis
-- (Highest Average Trip Distance by Pickup Location)
SELECT
    pickup_zone.borough AS pickup_location,
    ROUND(AVG(y.trip_distance), 2) AS avg_trip_distance,
    COUNT(*) AS total_trips
FROM silver.cleaned_yellow_taxi_trip y
LEFT JOIN silver.taxi_zones_mapping pickup_zone
    ON y.pulocationid = pickup_zone.locationid
GROUP BY pickup_zone.borough
ORDER BY avg_trip_distance DESC
LIMIT 1;

-- (Highest Average Revenue by Pickup Location)
SELECT
    pickup_zone.borough AS pickup_location,
    ROUND(AVG(y.total_amount), 2) AS avg_revenue,
    COUNT(*) AS total_trips
FROM silver.cleaned_yellow_taxi_trip y
LEFT JOIN silver.taxi_zones_mapping pickup_zone
    ON y.pulocationid = pickup_zone.locationid
GROUP BY pickup_zone.borough
ORDER BY avg_revenue DESC
LIMIT 1;


-- 3 Date, time, and Data Quality Analysis
-- Summary of Trips by Pickup Date
SELECT
    pickup_date,
    COUNT(*) AS total_trips,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(SUM(trip_distance), 2) AS total_trip_distance,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_minutes
FROM silver.cleaned_yellow_taxi_trip
GROUP BY pickup_date
ORDER BY pickup_date DESC

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
        pickup_zone.borough AS pickup_location,
        ROUND(AVG(y.total_amount), 2) AS avg_revenue,
        COUNT(*) AS total_trips
    FROM silver.cleaned_yellow_taxi_trip y
    LEFT JOIN silver.taxi_zones_mapping pickup_zone
        ON y.pulocationid = pickup_zone.locationid
    GROUP BY y.pulocationid, pickup_zone.borough
)
SELECT *
FROM pickup_location_revenue
ORDER BY avg_revenue DESC
LIMIT 10;

-- (Highest Pickup Location with Minimum Average Tip Amount)
SELECT
    pickup_zone.borough AS pickup_location,
    ROUND(AVG(y.tip_amount), 2) AS avg_tip_amount,
    COUNT(*) AS total_trips
FROM silver.cleaned_yellow_taxi_trip y
LEFT JOIN silver.taxi_zones_mapping pickup_zone
    ON y.pulocationid = pickup_zone.locationid
GROUP BY pickup_zone.borough
ORDER BY avg_tip_amount ASC
LIMIT 1;

-- Perbandingan revenue setiap hari terhadap rata-rata revenue harian
WITH daily_revenue AS (
    SELECT
        pickup_date,
        ROUND(SUM(total_amount), 2) AS total_revenue
    FROM silver.cleaned_yellow_taxi_trip
    GROUP BY pickup_date
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
    pickup_zone.borough AS pickup_location,
    ROUND(SUM(y.total_amount), 2) AS total_revenue,
    COUNT(*) AS total_trips,
    RANK() OVER (ORDER BY SUM(y.total_amount) DESC) AS revenue_rank
FROM silver.cleaned_yellow_taxi_trip y
LEFT JOIN silver.taxi_zones_mapping pickup_zone
    ON y.pulocationid = pickup_zone.locationid
GROUP BY pickup_zone.borough
ORDER BY revenue_rank;

-- Pickup Locations Ranked by Borough
SELECT
    pickup_zone.borough AS pickup_location,
    ROUND(SUM(y.total_amount), 2) AS total_revenue,
    COUNT(*) AS total_trips,
    RANK() OVER (PARTITION BY pickup_zone.borough ORDER BY SUM(y.total_amount) DESC) AS revenue_rank_within_borough
FROM silver.cleaned_yellow_taxi_trip y
LEFT JOIN silver.taxi_zones_mapping pickup_zone
    ON y.pulocationid = pickup_zone.locationid
GROUP BY pickup_zone.borough
ORDER BY pickup_zone.borough, revenue_rank_within_borough;

-- Moving Average by Trip Duration (7-day Moving Average)
WITH daily_trip_duration AS (
    SELECT
        pickup_date,
        ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration
    FROM silver.cleaned_yellow_taxi_trip
    GROUP BY pickup_date
)
SELECT
    pickup_date,
    avg_trip_duration,
    ROUND(AVG(avg_trip_duration) OVER (ORDER BY pickup_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_trip_duration_7_days
FROM daily_trip_duration
ORDER BY pickup_date;  