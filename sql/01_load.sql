-- 01_load.sql — Load BTS On-Time Performance CSVs into DuckDB and build cleaned tables.
--
-- Run from the project root:
--   python3 load.py
-- (load.py executes this file against data/flights.duckdb)
--
-- Source files: data/raw/*.csv — the 12 monthly files
--   On_Time_Reporting_Carrier_On_Time_Performance_(1987_present)_YYYY_M.csv
--   Sep 2025 – Aug 2026, downloaded from https://transtats.bts.gov (PREZIP).
-- Raw CSVs and the .duckdb file are git-ignored; only this script is versioned.

-- ---------------------------------------------------------------------------
-- 1. Raw load: all 12 monthly files, one row per scheduled flight.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE flights_raw AS
SELECT * FROM read_csv(
    'data/raw/*.csv',
    header = true,
    union_by_name = true
);

-- ---------------------------------------------------------------------------
-- 2. Cleaned flights table.
--
-- Cleaning decisions (see notes/cleaning_notes.md for the full discussion):
--   * Cancelled and diverted flights are KEPT in this table with flags, but
--     every delay metric in the analysis excludes them (a cancelled flight
--     has no arrival delay). Cancellation rate is measured separately.
--   * FlightDate is cast to DATE; scheduled times (CRSDepTime/CRSArrTime)
--     are stored as HHMM integers in the source. sched_dep_hour is derived
--     as (CRSDepTime // 100) % 24, so 2400 (midnight, end of day) maps to 0.
--   * Delay-cause minutes (CarrierDelay, WeatherDelay, NASDelay,
--     SecurityDelay, LateAircraftDelay) are NULL when the flight was not
--     delayed or the cause does not apply. NULL means "0 minutes attributed
--     to this cause" and is coalesced to 0 in analysis queries.
--   * ArrDelayMinutes / DepDelayMinutes are NULL for cancelled flights.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE flights AS
SELECT
    CAST(FlightDate AS DATE)                       AS flight_date,
    CAST(Year AS INTEGER)                          AS year,
    CAST(Month AS INTEGER)                         AS month,
    CAST(DayofMonth AS INTEGER)                    AS day_of_month,
    CAST(DayOfWeek AS INTEGER)                     AS day_of_week,
    Reporting_Airline                              AS airline_code,
    CAST(DOT_ID_Reporting_Airline AS INTEGER)      AS airline_dot_id,
    Tail_Number                                    AS tail_number,
    CAST(Flight_Number_Reporting_Airline AS INTEGER) AS flight_number,
    Origin                                         AS origin,
    OriginCityName                                 AS origin_city,
    OriginState                                    AS origin_state,
    Dest                                           AS dest,
    DestCityName                                   AS dest_city,
    DestState                                      AS dest_state,
    CRSDepTime                                     AS crs_dep_time,
    DepTime                                        AS dep_time,
    CRSArrTime                                     AS crs_arr_time,
    ArrTime                                        AS arr_time,
    CASE WHEN CRSDepTime IS NULL THEN NULL
         ELSE (CAST(CRSDepTime AS INTEGER) // 100) % 24 END AS sched_dep_hour,
    DepTimeBlk                                     AS dep_time_blk,
    ArrTimeBlk                                     AS arr_time_blk,
    CAST(DepDelayMinutes AS DOUBLE)                AS dep_delay_min,
    CAST(ArrDelayMinutes AS DOUBLE)                AS arr_delay_min,
    CAST(ArrDel15 AS INTEGER)                      AS arr_del15,
    CAST(DepDel15 AS INTEGER)                      AS dep_del15,
    CAST(Cancelled AS INTEGER)                     AS cancelled,
    CancellationCode                               AS cancellation_code,
    CAST(Diverted AS INTEGER)                      AS diverted,
    CAST(CarrierDelay AS DOUBLE)                   AS carrier_delay_min,
    CAST(WeatherDelay AS DOUBLE)                   AS weather_delay_min,
    CAST(NASDelay AS DOUBLE)                       AS nas_delay_min,
    CAST(SecurityDelay AS DOUBLE)                  AS security_delay_min,
    CAST(LateAircraftDelay AS DOUBLE)              AS late_aircraft_delay_min,
    CAST(Distance AS INTEGER)                      AS distance_miles,
    CAST(AirTime AS DOUBLE)                        AS air_time_min,
    CAST(ActualElapsedTime AS DOUBLE)              AS actual_elapsed_min,
    CAST(CRSElapsedTime AS DOUBLE)                 AS crs_elapsed_min
FROM flights_raw;

-- ---------------------------------------------------------------------------
-- 3. Dimensions.
--    airlines: IATA code -> BTS-published carrier name (see data/airlines.csv).
--    airports: airport code -> city/state, taken from the OTP file itself
--              (OriginCityName / OriginState), most frequent value per code.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE airlines AS
SELECT * FROM read_csv('data/airlines.csv', header = true);

CREATE OR REPLACE TABLE airports AS
SELECT
    airport,
    MAX(city) AS city,
    MAX(state) AS state
FROM (
    SELECT Origin AS airport, origin_city AS city, origin_state AS state FROM flights
    UNION ALL
    SELECT Dest AS airport, dest_city AS city, dest_state AS state FROM flights
)
GROUP BY airport;
