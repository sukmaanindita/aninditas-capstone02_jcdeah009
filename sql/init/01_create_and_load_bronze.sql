CREATE SCHEMA IF NOT EXISTS bronze;

DROP TABLE IF EXISTS bronze.raw_yellow_taxi_trip;
DROP TABLE IF EXISTS bronze.raw_taxi_zone_lookup;

CREATE TABLE bronze.raw_taxi_zone_lookup (
    locationid INTEGER PRIMARY KEY,
    borough VARCHAR(100),
    zone VARCHAR(255),
    service_zone VARCHAR(100),
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bronze.raw_yellow_taxi_trip (
    trip_id BIGSERIAL PRIMARY KEY,
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
    pickup_hour INTEGER,
    day_of_week VARCHAR(20),
    is_weekend BOOLEAN,
    trip_duration NUMERIC,
    time_period VARCHAR(30),
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_raw_yellow_trip_pulocation
        FOREIGN KEY (pulocationid)
        REFERENCES bronze.raw_taxi_zone_lookup (locationid),
    CONSTRAINT fk_raw_yellow_trip_dolocation
        FOREIGN KEY (dolocationid)
        REFERENCES bronze.raw_taxi_zone_lookup (locationid)
);

CREATE INDEX IF NOT EXISTS idx_raw_yellow_trip_pickup_datetime
ON bronze.raw_yellow_taxi_trip (tpep_pickup_datetime);

CREATE INDEX IF NOT EXISTS idx_raw_yellow_trip_pickup_date
ON bronze.raw_yellow_taxi_trip (pickup_date);

CREATE INDEX IF NOT EXISTS idx_raw_yellow_trip_payment_type
ON bronze.raw_yellow_taxi_trip (payment_type);

CREATE INDEX IF NOT EXISTS idx_raw_yellow_trip_location
ON bronze.raw_yellow_taxi_trip (pulocationid, dolocationid);

CREATE INDEX IF NOT EXISTS idx_raw_taxi_zone_borough
ON bronze.raw_taxi_zone_lookup (borough);
