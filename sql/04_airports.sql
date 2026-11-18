-- 04_airports.sql — Busiest airports and their delay rates.
-- Q3: Which airports handle the most traffic, and how often do flights
--     arriving / departing there run late?
-- Airport traffic = arrivals + departures. Arrival delay is measured on
-- flights arriving at the airport; departure delay on flights leaving it.

WITH arrivals AS (
    SELECT
        dest AS airport,
        COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) AS arrivals_operated,
        ROUND(100.0 * (1 - AVG(arr_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 IS NOT NULL)), 2) AS arrival_on_time_pct,
        ROUND(AVG(arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_arrival_delay_min
    FROM flights
    GROUP BY dest
),
departures AS (
    SELECT
        origin AS airport,
        COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) AS departures_operated,
        ROUND(100.0 * (1 - AVG(dep_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND dep_del15 IS NOT NULL)), 2) AS departure_on_time_pct,
        ROUND(AVG(dep_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_departure_delay_min
    FROM flights
    GROUP BY origin
),
cancelled AS (
    SELECT
        origin AS airport,
        SUM(cancelled) AS cancelled_departures,
        COUNT(*) AS scheduled_departures
    FROM flights
    GROUP BY origin
)
SELECT
    ap.airport,
    ap.city,
    ap.state,
    ar.arrivals_operated + dp.departures_operated AS total_flights_handled,
    ar.arrivals_operated,
    dp.departures_operated,
    ar.arrival_on_time_pct,
    ar.avg_arrival_delay_min,
    dp.departure_on_time_pct,
    dp.avg_departure_delay_min,
    ROUND(100.0 * c.cancelled_departures / c.scheduled_departures, 2) AS cancellation_rate_pct
FROM airports ap
JOIN arrivals ar ON ar.airport = ap.airport
JOIN departures dp ON dp.airport = ap.airport
JOIN cancelled c ON c.airport = ap.airport
ORDER BY total_flights_handled DESC
LIMIT 30;
