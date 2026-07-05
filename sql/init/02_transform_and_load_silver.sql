CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

DROP VIEW IF EXISTS gold.trip_detail_view;
DROP VIEW IF EXISTS gold.daily_trip_summary;
DROP VIEW IF EXISTS gold.location_performance;
DROP VIEW IF EXISTS gold.payment_method_summary;
DROP VIEW IF EXISTS gold.weekend_trip_summary;
DROP VIEW IF EXISTS gold.data_quality_summary;
DROP TABLE IF EXISTS silver.data_quality_issues;
DROP TABLE IF EXISTS silver.cleaned_yellow_taxi_trip;
DROP TABLE IF EXISTS silver.taxi_zones_mapping;

CREATE TABLE silver.taxi_zones_mapping (
    locationid INTEGER PRIMARY KEY,
    borough VARCHAR(100),
    zone VARCHAR(255),
    service_zone VARCHAR(100),
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.taxi_zones_mapping (
    locationid,
    borough,
    zone,
    service_zone
)
SELECT
    locationid,
    borough,
    zone,
    service_zone
FROM bronze.raw_taxi_zone_lookup;

CREATE TABLE silver.cleaned_yellow_taxi_trip (
    cleaned_trip_id BIGSERIAL PRIMARY KEY,
    vendorid INTEGER,
    tpep_pickup_datetime TIMESTAMP,
    tpep_dropoff_datetime TIMESTAMP,
    passenger_count NUMERIC,
    trip_distance NUMERIC,
    ratecodeid NUMERIC,
    store_and_fwd_flag VARCHAR(20),
    pulocationid INTEGER,
    dolocationid INTEGER,
    payment_type VARCHAR(50),
    fare_amount NUMERIC,
    extra NUMERIC,
    mta_tax NUMERIC,
    tip_amount NUMERIC,
    tolls_amount NUMERIC,
    improvement_surcharge NUMERIC,
    total_amount NUMERIC,
    congestion_surcharge NUMERIC,
    airport_fee NUMERIC,
    cbd_congestion_fee NUMERIC,
    pickup_date DATE,
    pickup_time TIME,
    pickup_day_name VARCHAR(20),
    is_weekend VARCHAR(1),
    trip_duration_minutes NUMERIC,
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- insert data cleaned
INSERT INTO silver.cleaned_yellow_taxi_trip (
    vendorid,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    ratecodeid,
    store_and_fwd_flag,
    pulocationid,
    dolocationid,
    payment_type,
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
    pickup_time,
    pickup_day_name,
    is_weekend,
    trip_duration_minutes
)
    SELECT
        rytt.vendorid,
        rytt.tpep_pickup_datetime,
        rytt.tpep_dropoff_datetime,
        rytt.passenger_count,
        rytt.trip_distance,
        rytt.ratecodeid,
        rytt.store_and_fwd_flag,
        rytt.pulocationid,
        rytt.dolocationid,
        rytt.payment_type,
        rytt.fare_amount,
        rytt.extra,
        rytt.mta_tax,
        rytt.tip_amount,
        rytt.tolls_amount,
        rytt.improvement_surcharge,
        rytt.total_amount,
        rytt.congestion_surcharge,
        rytt.airport_fee,
        rytt.cbd_congestion_fee,
        rytt.tpep_pickup_datetime::DATE AS pickup_date,
        rytt.tpep_pickup_datetime::TIME AS pickup_time,
        TRIM(TO_CHAR(rytt.tpep_pickup_datetime, 'Day')) AS pickup_day_name,
        CASE
            WHEN TRIM(TO_CHAR(rytt.tpep_pickup_datetime, 'Day')) IN ('Saturday', 'Sunday') THEN 'Y'
            ELSE 'N'
        END AS is_weekend,
        ROUND(EXTRACT(EPOCH FROM (rytt.tpep_dropoff_datetime - rytt.tpep_pickup_datetime)) / 60) AS trip_duration_minutes
    FROM bronze.raw_yellow_taxi_trip rytt
    WHERE rytt.vendorid IS NOT NULL
        AND rytt.tpep_pickup_datetime IS NOT NULL
        AND rytt.tpep_dropoff_datetime IS NOT NULL
        AND rytt.pulocationid IS NOT NULL
        AND rytt.dolocationid IS NOT NULL
        AND rytt.passenger_count IS NOT NULL
        AND rytt.trip_distance IS NOT NULL
        AND rytt.total_amount IS NOT NULL
        AND rytt.tpep_dropoff_datetime > rytt.tpep_pickup_datetime
        AND rytt.passenger_count > 0
        AND rytt.trip_distance > 0
        AND rytt.total_amount >= 0;


CREATE TABLE silver.data_quality_issues (
    issue_id BIGSERIAL PRIMARY KEY,
    vendorid INTEGER,
    tpep_pickup_datetime TIMESTAMP,
    tpep_dropoff_datetime TIMESTAMP,
    passenger_count NUMERIC,
    trip_distance NUMERIC,
    ratecodeid NUMERIC,
    store_and_fwd_flag VARCHAR(20),
    pulocationid INTEGER,
    dolocationid INTEGER,
    payment_type VARCHAR(50),
    fare_amount NUMERIC,
    extra NUMERIC,
    mta_tax NUMERIC,
    tip_amount NUMERIC,
    tolls_amount NUMERIC,
    improvement_surcharge NUMERIC,
    total_amount NUMERIC,
    congestion_surcharge NUMERIC,
    airport_fee NUMERIC,
    cbd_congestion_fee NUMERIC,
    error_type VARCHAR(50),
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- insert data quality issues
INSERT INTO silver.data_quality_issues (
    vendorid,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    ratecodeid,
    store_and_fwd_flag,
    pulocationid,
    dolocationid,
    payment_type,
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
    error_type
)
SELECT
    b.vendorid,
    b.tpep_pickup_datetime,
    b.tpep_dropoff_datetime,
    b.passenger_count,
    b.trip_distance,
    b.ratecodeid,
    b.store_and_fwd_flag,
    b.pulocationid,
    b.dolocationid,
    b.payment_type,
    b.fare_amount,
    b.extra,
    b.mta_tax,
    b.tip_amount,
    b.tolls_amount,
    b.improvement_surcharge,
    b.total_amount,
    b.congestion_surcharge,
    b.airport_fee,
    b.cbd_congestion_fee,
    CASE
        WHEN b.vendorid IS NULL
            OR b.tpep_pickup_datetime IS NULL
            OR b.tpep_dropoff_datetime IS NULL
            OR b.pulocationid IS NULL
            OR b.dolocationid IS NULL
            OR b.passenger_count IS NULL
            OR b.trip_distance IS NULL
            OR b.total_amount IS NULL THEN 'Data Invalid'
        WHEN b.tpep_pickup_datetime >= b.tpep_dropoff_datetime THEN 'Duration Invalid'
        WHEN b.trip_distance <= 0 THEN 'Distance Invalid'
        WHEN b.passenger_count <= 0 THEN 'Passenger Invalid'
        WHEN b.total_amount < 0 THEN 'Amount Invalid'
    END AS error_type
FROM bronze.raw_yellow_taxi_trip b
WHERE b.vendorid IS NULL
    OR b.tpep_pickup_datetime IS NULL
    OR b.tpep_dropoff_datetime IS NULL
    OR b.pulocationid IS NULL
    OR b.dolocationid IS NULL
    OR b.passenger_count IS NULL
    OR b.trip_distance IS NULL
    OR b.total_amount IS NULL
    OR b.tpep_pickup_datetime >= b.tpep_dropoff_datetime
    OR b.passenger_count <= 0
    OR b.trip_distance <= 0
    OR b.total_amount < 0;

-- create indexes for silver tables
CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_pickup_datetime
ON silver.cleaned_yellow_taxi_trip (tpep_pickup_datetime);

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_pickup_date
ON silver.cleaned_yellow_taxi_trip (pickup_date);

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_payment_type
ON silver.cleaned_yellow_taxi_trip (payment_type);

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_location
ON silver.cleaned_yellow_taxi_trip (pulocationid, dolocationid);

CREATE INDEX IF NOT EXISTS idx_taxi_zones_mapping_borough
ON silver.taxi_zones_mapping (borough);

CREATE INDEX IF NOT EXISTS idx_data_quality_issues_error_type
ON silver.data_quality_issues (error_type);
