CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

DROP VIEW IF EXISTS gold.vw_trip_enriched;
DROP VIEW IF EXISTS gold.vw_daily_trip_summary;
DROP VIEW IF EXISTS gold.vw_zone_performance;
DROP VIEW IF EXISTS gold.trip_detail_view;
DROP VIEW IF EXISTS gold.daily_trip_summary;
DROP VIEW IF EXISTS gold.location_performance;
DROP VIEW IF EXISTS gold.payment_method_summary;
DROP VIEW IF EXISTS gold.weekend_trip_summary;
DROP VIEW IF EXISTS gold.data_quality_summary;
DROP TABLE IF EXISTS silver.data_quality_issues CASCADE;
DROP TABLE IF EXISTS silver.cleaned_yellow_taxi_trip CASCADE;
DROP TABLE IF EXISTS silver.taxi_zones_mapping CASCADE;

CREATE TABLE silver.taxi_zones_mapping (
    locationid INTEGER PRIMARY KEY,
    borough VARCHAR(100) NOT NULL,
    zone VARCHAR(255) NOT NULL,
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
    COALESCE(borough, 'Unknown') AS borough,
    COALESCE(zone, 'Unknown') AS zone,
    COALESCE(service_zone, 'Unknown') AS service_zone
FROM bronze.raw_taxi_zone_lookup
WHERE locationid IS NOT NULL;

CREATE TABLE silver.cleaned_yellow_taxi_trip (
    cleaned_trip_id BIGSERIAL PRIMARY KEY,
    vendor_id INTEGER NOT NULL,
    tpep_pickup_datetime TIMESTAMP NOT NULL,
    tpep_dropoff_datetime TIMESTAMP NOT NULL,
    passenger_count NUMERIC NOT NULL CHECK (passenger_count > 0),
    trip_distance NUMERIC NOT NULL CHECK (trip_distance > 0),
    rate_code_id NUMERIC,
    store_and_fwd_flag VARCHAR(20),
    store_and_fwd_label VARCHAR(30),
    pu_location_id INTEGER NOT NULL REFERENCES silver.taxi_zones_mapping (locationid),
    pickup_borough VARCHAR(100),
    pickup_zone VARCHAR(255),
    do_location_id INTEGER NOT NULL REFERENCES silver.taxi_zones_mapping (locationid),
    dropoff_borough VARCHAR(100),
    dropoff_zone VARCHAR(255),
    payment_type VARCHAR(50) NOT NULL,
    payment_type_label VARCHAR(50) NOT NULL,
    fare_amount NUMERIC CHECK (fare_amount >= 0),
    extra NUMERIC,
    mta_tax NUMERIC,
    tip_amount NUMERIC CHECK (tip_amount >= 0),
    tolls_amount NUMERIC,
    improvement_surcharge NUMERIC,
    total_amount NUMERIC NOT NULL CHECK (total_amount >= 0),
    congestion_surcharge NUMERIC,
    airport_fee NUMERIC,
    cbd_congestion_fee NUMERIC,
    pickup_date DATE NOT NULL,
    pickup_hour INTEGER NOT NULL CHECK (pickup_hour BETWEEN 0 AND 23),
    pickup_time TIME NOT NULL,
    pickup_day_name VARCHAR(20) NOT NULL,
    is_weekend VARCHAR(1) NOT NULL CHECK (is_weekend IN ('Y', 'N')),
    time_period VARCHAR(30) NOT NULL,
    trip_duration_minutes NUMERIC NOT NULL CHECK (trip_duration_minutes > 0),
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.cleaned_yellow_taxi_trip (
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
    trip_duration_minutes
)
SELECT
    rytt.vendorid AS vendor_id,
    rytt.tpep_pickup_datetime,
    rytt.tpep_dropoff_datetime,
    rytt.passenger_count,
    rytt.trip_distance,
    rytt.ratecodeid AS rate_code_id,
    rytt.store_and_fwd_flag,
    CASE
        WHEN rytt.store_and_fwd_flag = 'Y' THEN 'Store and Forward'
        WHEN rytt.store_and_fwd_flag = 'N' THEN 'Normal'
        ELSE 'Unknown'
    END AS store_and_fwd_label,
    rytt.pulocationid AS pu_location_id,
    pickup_zone.borough AS pickup_borough,
    pickup_zone.zone AS pickup_zone,
    rytt.dolocationid AS do_location_id,
    dropoff_zone.borough AS dropoff_borough,
    dropoff_zone.zone AS dropoff_zone,
    rytt.payment_type,
    CASE rytt.payment_type::TEXT
        WHEN '1' THEN 'Credit Card'
        WHEN '2' THEN 'Cash'
        WHEN '3' THEN 'No Charge'
        WHEN '4' THEN 'Dispute'
        WHEN '5' THEN 'Unknown'
        WHEN '6' THEN 'Voided Trip'
        WHEN '0' THEN 'Unknown'
        ELSE 'Unknown'
    END AS payment_type_label,
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
    EXTRACT(HOUR FROM rytt.tpep_pickup_datetime)::INTEGER AS pickup_hour,
    rytt.tpep_pickup_datetime::TIME AS pickup_time,
    TRIM(TO_CHAR(rytt.tpep_pickup_datetime, 'Day')) AS pickup_day_name,
    CASE
        WHEN TRIM(TO_CHAR(rytt.tpep_pickup_datetime, 'Day')) IN ('Saturday', 'Sunday') THEN 'Y'
        ELSE 'N'
    END AS is_weekend,
    CASE
        WHEN EXTRACT(HOUR FROM rytt.tpep_pickup_datetime) BETWEEN 0 AND 5 THEN 'Late Night'
        WHEN EXTRACT(HOUR FROM rytt.tpep_pickup_datetime) BETWEEN 6 AND 10 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM rytt.tpep_pickup_datetime) BETWEEN 11 AND 15 THEN 'Afternoon'
        WHEN EXTRACT(HOUR FROM rytt.tpep_pickup_datetime) BETWEEN 16 AND 19 THEN 'Evening Rush'
        ELSE 'Night'
    END AS time_period,
    (EXTRACT(EPOCH FROM (rytt.tpep_dropoff_datetime - rytt.tpep_pickup_datetime)) / 60)::NUMERIC AS trip_duration_minutes
FROM bronze.raw_yellow_taxi_trip rytt
JOIN silver.taxi_zones_mapping pickup_zone
    ON rytt.pulocationid = pickup_zone.locationid
JOIN silver.taxi_zones_mapping dropoff_zone
    ON rytt.dolocationid = dropoff_zone.locationid
WHERE rytt.vendorid IS NOT NULL
    AND rytt.tpep_pickup_datetime IS NOT NULL
    AND rytt.tpep_dropoff_datetime IS NOT NULL
    AND rytt.pulocationid IS NOT NULL
    AND rytt.dolocationid IS NOT NULL
    AND rytt.passenger_count IS NOT NULL
    AND rytt.trip_distance IS NOT NULL
    AND rytt.payment_type IS NOT NULL
    AND rytt.total_amount IS NOT NULL
    AND rytt.tpep_dropoff_datetime > rytt.tpep_pickup_datetime
    AND rytt.passenger_count > 0
    AND rytt.trip_distance > 0
    AND COALESCE(rytt.fare_amount, 0) >= 0
    AND COALESCE(rytt.tip_amount, 0) >= 0
    AND rytt.total_amount >= 0;

CREATE TABLE silver.data_quality_issues (
    issue_id BIGSERIAL PRIMARY KEY,
    vendor_id INTEGER,
    tpep_pickup_datetime TIMESTAMP,
    tpep_dropoff_datetime TIMESTAMP,
    passenger_count NUMERIC,
    trip_distance NUMERIC,
    rate_code_id NUMERIC,
    store_and_fwd_flag VARCHAR(20),
    pu_location_id INTEGER,
    do_location_id INTEGER,
    payment_type VARCHAR(50),
    fare_amount NUMERIC,
    tip_amount NUMERIC,
    total_amount NUMERIC,
    error_type VARCHAR(50) NOT NULL,
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.data_quality_issues (
    vendor_id,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,
    rate_code_id,
    store_and_fwd_flag,
    pu_location_id,
    do_location_id,
    payment_type,
    fare_amount,
    tip_amount,
    total_amount,
    error_type
)
SELECT
    b.vendorid AS vendor_id,
    b.tpep_pickup_datetime,
    b.tpep_dropoff_datetime,
    b.passenger_count,
    b.trip_distance,
    b.ratecodeid AS rate_code_id,
    b.store_and_fwd_flag,
    b.pulocationid AS pu_location_id,
    b.dolocationid AS do_location_id,
    b.payment_type,
    b.fare_amount,
    b.tip_amount,
    b.total_amount,
    CASE
        WHEN b.vendorid IS NULL
            OR b.tpep_pickup_datetime IS NULL
            OR b.tpep_dropoff_datetime IS NULL
            OR b.pulocationid IS NULL
            OR b.dolocationid IS NULL
            OR b.passenger_count IS NULL
            OR b.trip_distance IS NULL
            OR b.payment_type IS NULL
            OR b.total_amount IS NULL THEN 'Data Invalid'
        WHEN pickup_zone.locationid IS NULL OR dropoff_zone.locationid IS NULL THEN 'Location Invalid'
        WHEN b.tpep_pickup_datetime >= b.tpep_dropoff_datetime THEN 'Duration Invalid'
        WHEN b.trip_distance <= 0 THEN 'Distance Invalid'
        WHEN b.passenger_count <= 0 THEN 'Passenger Invalid'
        WHEN COALESCE(b.fare_amount, 0) < 0 THEN 'Fare Invalid'
        WHEN COALESCE(b.tip_amount, 0) < 0 THEN 'Tip Invalid'
        WHEN b.total_amount < 0 THEN 'Amount Invalid'
    END AS error_type
FROM bronze.raw_yellow_taxi_trip b
LEFT JOIN silver.taxi_zones_mapping pickup_zone
    ON b.pulocationid = pickup_zone.locationid
LEFT JOIN silver.taxi_zones_mapping dropoff_zone
    ON b.dolocationid = dropoff_zone.locationid
WHERE b.vendorid IS NULL
    OR b.tpep_pickup_datetime IS NULL
    OR b.tpep_dropoff_datetime IS NULL
    OR b.pulocationid IS NULL
    OR b.dolocationid IS NULL
    OR b.passenger_count IS NULL
    OR b.trip_distance IS NULL
    OR b.payment_type IS NULL
    OR b.total_amount IS NULL
    OR pickup_zone.locationid IS NULL
    OR dropoff_zone.locationid IS NULL
    OR b.tpep_pickup_datetime >= b.tpep_dropoff_datetime
    OR b.passenger_count <= 0
    OR b.trip_distance <= 0
    OR COALESCE(b.fare_amount, 0) < 0
    OR COALESCE(b.tip_amount, 0) < 0
    OR b.total_amount < 0;

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_pickup_datetime
ON silver.cleaned_yellow_taxi_trip (tpep_pickup_datetime);

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_pickup_date
ON silver.cleaned_yellow_taxi_trip (pickup_date);

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_pickup_hour
ON silver.cleaned_yellow_taxi_trip (pickup_hour);

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_payment_type
ON silver.cleaned_yellow_taxi_trip (payment_type_label);

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_location
ON silver.cleaned_yellow_taxi_trip (pu_location_id, do_location_id);

CREATE INDEX IF NOT EXISTS idx_cleaned_yellow_taxi_trip_pickup_zone
ON silver.cleaned_yellow_taxi_trip (pickup_borough, pickup_zone);

CREATE INDEX IF NOT EXISTS idx_taxi_zones_mapping_borough
ON silver.taxi_zones_mapping (borough);

CREATE INDEX IF NOT EXISTS idx_data_quality_issues_error_type
ON silver.data_quality_issues (error_type);
