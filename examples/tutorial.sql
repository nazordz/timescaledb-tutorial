-- DROP TABLE IF EXISTS
DROP TABLE IF EXISTS energy_data;

-- Create the table
CREATE TABLE energy_data (
    timestamp TIMESTAMPTZ NOT NULL,
    consumption FLOAT NOT NULL
);

-- Create a hypertable on the timestamp column
SELECT create_hypertable( 'energy_data', 'timestamp');
-- Generate and insert sample data for 10,000,000 records
INSERT INTO energy_data (timestamp, consumption)
SELECT
    NOW() - INTERVAL '1 day' * (random() * 365)::int AS timestamp,
    random () * 1000 AS consumption
FROM generate_series(1, 10000000);

-- example to create unique indexes on a hypertable
CREATE UNIQUE INDEX idx_deviceid_time
  ON hypertable_example(device_id, time);
 
------
-- tutorial by timescale below (https://docs.timescale.com/getting-started/latest/tables-hypertables/)
CREATE TABLE stocks_real_time (
  time TIMESTAMPTZ NOT NULL,
  symbol TEXT NOT NULL,
  price DOUBLE PRECISION NULL,
  day_volume INT NULL
);

-- hypertables = tables that automatically partition your data by time
SELECT create_hypertable('stocks_real_time', by_range('time'));
SELECT set_chunk_time_interval('stocks_real_time', INTERVAL '24 hours');


CREATE INDEX ix_symbol_time ON stocks_real_time (symbol, time DESC);

CREATE TABLE company (
  symbol TEXT NOT NULL,
  name TEXT NOT NULL
);

SELECT * FROM stocks_real_time srt
WHERE symbol='TSLA' and day_volume is not null
ORDER BY time DESC, day_volume desc
limit 10

SELECT symbol, first(price,time), last(price, time)
FROM stocks_real_time srt
WHERE time > now() - INTERVAL '7 days'
GROUP BY symbol
ORDER BY symbol
LIMIT 10;


SELECT time_bucket('1 hour', time) AS bucket,
    first(price,time),
    last(price, time)
FROM stocks_real_time srt
WHERE time > now() - INTERVAL '7 days'
GROUP BY bucket;


SELECT
  time_bucket('1 day', time) AS bucket,
  symbol,
  max(price) AS high,
  first(price, time) AS open,
  last(price, time) AS close,
  min(price) AS low
FROM stocks_real_time srt
WHERE time > now() - INTERVAL '1 week'
GROUP BY bucket, symbol
ORDER BY bucket, symbol
LIMIT 10;

-- continuous aggregate = Continuous aggregates are a kind of hypertable that is refreshed automatically 
-- in the background as new data is added, or old data is modified
CREATE MATERIALIZED VIEW stock_candlestick_daily
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 day', "time") AS day,
  symbol,
  max(price) AS high,
  first(price, time) AS open,
  last(price, time) AS close,
  min(price) AS low
FROM stocks_real_time srt
GROUP BY day, symbol;

-- all stocks
SELECT * FROM stock_candlestick_daily
ORDER BY day DESC, symbol
LIMIT 10;

-- tesla stock
SELECT * FROM stock_candlestick_daily
WHERE symbol='TSLA'
ORDER BY day DESC
LIMIT 10;

CREATE MATERIALIZED VIEW one_day_candle
WITH (timescaledb.continuous) AS
    SELECT
        time_bucket('1 day', time) AS bucket,
        symbol,
        FIRST(price, time) AS "open",
        MAX(price) AS high,
        MIN(price) AS low,
        LAST(price, time) AS "close",
        LAST(day_volume, time) AS day_volume
    FROM stocks_real_time
    GROUP BY bucket, symbol;

-- refresh policy
SELECT add_continuous_aggregate_policy('one_day_candle',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');

SELECT * FROM one_day_candle
WHERE symbol = 'TSLA' AND bucket >= NOW() - INTERVAL '14 days'
ORDER BY bucket;

-- enable compresion for stocks_real_time table
ALTER TABLE stocks_real_time 
SET (
    timescaledb.compress, 
    timescaledb.compress_segmentby='symbol', 
    timescaledb.compress_orderby='time DESC'
);

-- compress hypertable
SELECT compress_chunk(c) from show_chunks('stocks_real_time') c;

-- comparison
SELECT 
    pg_size_pretty(before_compression_total_bytes) as before,
    pg_size_pretty(after_compression_total_bytes) as after
 FROM hypertable_compression_stats('stocks_real_time');
 
-- Add a compression policy
SELECT add_compression_policy('stocks_real_time', INTERVAL '8 days');

-- MATERIALIZED VIEW one_hour_candle
CREATE MATERIALIZED VIEW one_hour_candle
WITH (timescaledb.continuous) AS
    SELECT
        time_bucket('1 hour', time) AS bucket,
        symbol,
        FIRST(price, time) AS "open",
        MAX(price) AS high,
        MIN(price) AS low,
        LAST(price, time) AS "close",
        LAST(day_volume, time) AS day_volume
    FROM stocks_real_time
    GROUP BY bucket, symbol;
    
SELECT add_continuous_aggregate_policy('one_hour_candle',
start_offset => INTERVAL '3 hours',
end_offset => INTERVAL '1 hour',
schedule_interval => INTERVAL '1 hour');

SELECT * FROM one_hour_candle
WHERE symbol = 'TSLA' AND bucket >= NOW() - INTERVAL '1 week'
ORDER BY bucket;


-- transport case
CREATE TABLE "rides"(
    vendor_id TEXT,
    pickup_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    dropoff_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    passenger_count NUMERIC,
    trip_distance NUMERIC,
    pickup_longitude  NUMERIC,
    pickup_latitude   NUMERIC,
    rate_code         INTEGER,
    dropoff_longitude NUMERIC,
    dropoff_latitude  NUMERIC,
    payment_type INTEGER,
    fare_amount NUMERIC,
    extra NUMERIC,
    mta_tax NUMERIC,
    tip_amount NUMERIC,
    tolls_amount NUMERIC,
    improvement_surcharge NUMERIC,
    total_amount NUMERIC
);

-- create hypertable with chunk_time_interval to 7 days
SELECT create_hypertable('rides', by_range('pickup_datetime', INTERVAL '7 day'), create_default_indexes=>FALSE);
SELECT add_dimension('rides', by_hash('payment_type', 2));

CREATE INDEX ON rides (vendor_id, pickup_datetime DESC);
CREATE INDEX ON rides (rate_code, pickup_datetime DESC);
CREATE INDEX ON rides (passenger_count, pickup_datetime DESC);

select show_chunks('rides');

CREATE TABLE IF NOT EXISTS "payment_types"(
    payment_type INTEGER,
    description TEXT
);
INSERT INTO payment_types(payment_type, description) VALUES
(1, 'credit card'),
(2, 'cash'),
(3, 'no charge'),
(4, 'dispute'),
(5, 'unknown'),
(6, 'voided trip');


CREATE TABLE IF NOT EXISTS "rates"(
    rate_code   INTEGER,
    description TEXT
);
INSERT INTO rates(rate_code, description) VALUES
(1, 'standard rate'),
(2, 'JFK'),
(3, 'Newark'),
(4, 'Nassau or Westchester'),
(5, 'negotiated fare'),
(6, 'group ride');

SELECT * FROM rides LIMIT 5;

-- How many rides take place every day?
SELECT 
	date_trunc('day', pickup_datetime) as day,
	COUNT(*) 
FROM 
	rides
WHERE 
	pickup_datetime < '2016-01-08'
GROUP BY day
ORDER BY day;

-- average fare amount
SELECT 
	date_trunc('day', pickup_datetime) AS day,
	avg(fare_amount)
from
	rides
WHERE 
	pickup_datetime < '2016-01-08'
GROUP BY day
ORDER BY day;

-- How many rides of each rate type were taken?
select
	rates.description,
	COUNT(vendor_id) AS num_trips
FROM rides
JOIN rates ON rides.rate_code = rates.rate_code
WHERE pickup_datetime < '2016-01-08'
GROUP BY rates.description
ORDER BY LOWER(rates.description);

-- Finding what kind of trips are going to and from airports
SELECT 
	rates.description,
    COUNT(vendor_id) AS num_trips,
    AVG(dropoff_datetime - pickup_datetime) AS avg_trip_duration,
    AVG(total_amount) AS avg_total,
    CEIL(AVG(passenger_count)) AS avg_passengers
FROM rides
JOIN rates ON rides.rate_code = rates.rate_code
WHERE rides.rate_code IN (2,3) AND pickup_datetime < '2016-01-08'
GROUP BY rates.description
ORDER BY rates.description;

-- Finding how many rides took place on New Year's Day 2016
select
	time_bucket('30 minute', pickup_datetime) AS thirty_min,
	count(*)
FROM rides
WHERE pickup_datetime < '2016-01-02 00:00'
GROUP BY thirty_min
ORDER BY thirty_min;

--  timescaledb_information;
select
	*
from
	timescaledb_information.dimensions;

-- Note:
-- You cannot add a column with constraints or defaults to a hypertable that has compression enabled.
-- To add the column, you need to decompress the data in the hypertable, add the column, and then compress the data.


