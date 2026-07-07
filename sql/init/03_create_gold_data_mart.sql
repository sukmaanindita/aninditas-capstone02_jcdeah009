CREATE SCHEMA IF NOT EXISTS gold;

CREATE OR REPLACE VIEW gold.vw_trip_enriched AS
SELECT
    cleaned_trip_id,
    vendor_id,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    rate_code_id,
    store_and_fwd_flag,
    store_and_fwd_label,
    pu_location_id,
    pickup_borough,
    pickup_zone,
    do_location_id,
    dropoff_borough,
    dropoff_zone,
    payment_type,
    payment_type_label,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    congestion_surcharge,
    airport_fee,
    cbd_congestion_fee,
    pickup_date,
    pickup_hour,
    pickup_time,
    pickup_day_name,
    is_weekend,
    time_period,
    trip_duration_minutes,
    loaded_at
FROM silver.cleaned_yellow_taxi_trip;

CREATE OR REPLACE VIEW gold.vw_daily_trip_summary AS
SELECT
    pickup_date,
    COUNT(*) AS total_trips,
    SUM(passenger_count) AS total_passengers,
    ROUND(SUM(trip_distance), 2) AS total_trip_distance,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_revenue,
    ROUND(AVG(fare_amount), 2) AS avg_fare,
    ROUND(AVG(tip_amount), 2) AS avg_tip,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_minutes
FROM silver.cleaned_yellow_taxi_trip
GROUP BY pickup_date;

CREATE OR REPLACE VIEW gold.vw_zone_performance AS
WITH pickup_summary AS (
    SELECT
        pu_location_id AS locationid,
        pickup_borough AS borough,
        pickup_zone AS zone,
        COUNT(*) AS total_pickup_trips,
        ROUND(SUM(total_amount), 2) AS total_revenue,
        ROUND(AVG(fare_amount), 2) AS avg_fare,
        ROUND(AVG(tip_amount), 2) AS avg_tip,
        ROUND(AVG(trip_distance), 2) AS avg_trip_distance,
        ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_minutes
    FROM silver.cleaned_yellow_taxi_trip
    GROUP BY pu_location_id, pickup_borough, pickup_zone
),
dropoff_summary AS (
    SELECT
        do_location_id AS locationid,
        COUNT(*) AS total_dropoff_trips
    FROM silver.cleaned_yellow_taxi_trip
    GROUP BY do_location_id
)
SELECT
    ps.locationid,
    ps.borough,
    ps.zone,
    ps.total_pickup_trips,
    COALESCE(ds.total_dropoff_trips, 0) AS total_dropoff_trips,
    ps.total_revenue,
    ps.avg_fare,
    ps.avg_tip,
    ps.avg_trip_distance,
    ps.avg_trip_duration_minutes
FROM pickup_summary ps
LEFT JOIN dropoff_summary ds
    ON ps.locationid = ds.locationid;
