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