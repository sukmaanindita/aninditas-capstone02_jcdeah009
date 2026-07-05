CREATE SCHEMA IF NOT EXISTS gold;

CREATE OR REPLACE VIEW gold.vw_trip_enriched AS
SELECT
    y.cleaned_trip_id,
    y.vendorid,
    y.tpep_pickup_datetime,
    y.tpep_dropoff_datetime,
    y.passenger_count,
    y.trip_distance,
    y.ratecodeid,
    y.store_and_fwd_flag,
    y.pulocationid,
    pickup_zone.borough AS pickup_location,
    pickup_zone.zone AS pickup_zone,
    y.dolocationid,
    dropoff_zone.borough AS dropoff_location,
    dropoff_zone.zone AS dropoff_zone,
    y.payment_type,
    y.fare_amount,
    y.extra,
    y.mta_tax,
    y.tip_amount,
    y.tolls_amount,
    y.improvement_surcharge,
    y.total_amount,
    y.congestion_surcharge,
    y.airport_fee,
    y.cbd_congestion_fee,
    y.pickup_date,
    y.pickup_time,
    y.pickup_day_name,
    y.is_weekend,
    y.trip_duration_minutes,
    y.loaded_at
FROM silver.cleaned_yellow_taxi_trip y
LEFT JOIN silver.taxi_zones_mapping pickup_zone
    ON y.pulocationid = pickup_zone.locationid
LEFT JOIN silver.taxi_zones_mapping dropoff_zone
    ON y.dolocationid = dropoff_zone.locationid;

CREATE OR REPLACE VIEW gold.vw_daily_trip_summary AS
SELECT
    pickup_date,
    COUNT(*) AS total_trips,
    SUM(passenger_count) AS total_passengers,
    ROUND(SUM(trip_distance), 2) AS total_trip_distance,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_revenue_per_trip,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_minutes
FROM silver.cleaned_yellow_taxi_trip
GROUP BY pickup_date;

CREATE OR REPLACE VIEW gold.vw_zone_performance AS
SELECT
    pickup_zone.borough AS pickup_location,
    dropoff_zone.borough AS dropoff_location,
    COUNT(*) AS total_trips,
    ROUND(SUM(y.total_amount), 2) AS total_revenue,
    ROUND(AVG(y.total_amount), 2) AS avg_revenue,
    ROUND(AVG(y.trip_distance), 2) AS avg_trip_distance,
    ROUND(AVG(y.trip_duration_minutes), 2) AS avg_trip_duration_minutes
FROM silver.cleaned_yellow_taxi_trip y
LEFT JOIN silver.taxi_zones_mapping pickup_zone
    ON y.pulocationid = pickup_zone.locationid
LEFT JOIN silver.taxi_zones_mapping dropoff_zone
    ON y.dolocationid = dropoff_zone.locationid
GROUP BY pickup_zone.borough, dropoff_zone.borough;
