-- 03_airlines.sql — Worst and best airlines by on-time %.
-- Q1: Which airlines are most / least reliable?
-- Q2: How does each airline rank within each airport it serves?
-- Operated flights only (not cancelled, not diverted).

-- Q1: Airline summary, ranked by on-time %.
WITH airline AS (
    SELECT
        f.airline_code,
        a.airline_name,
        COUNT(*) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0) AS operated_flights,
        SUM(f.cancelled) AS cancelled_flights,
        ROUND(100.0 * SUM(f.cancelled) / COUNT(*), 2) AS cancellation_rate_pct,
        ROUND(100.0 * (1 - AVG(f.arr_del15) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0 AND f.arr_del15 IS NOT NULL)), 2) AS on_time_pct,
        ROUND(AVG(f.arr_delay_min) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0), 2) AS avg_arrival_delay_min
    FROM flights f
    JOIN airlines a ON a.iata_code = f.airline_code
    GROUP BY f.airline_code, a.airline_name
)
SELECT
    *,
    RANK() OVER (ORDER BY on_time_pct DESC) AS on_time_rank_best,
    RANK() OVER (ORDER BY on_time_pct ASC) AS on_time_rank_worst
FROM airline
ORDER BY on_time_pct DESC;

-- Q2: Airline rank within each airport (origin). Uses a window function so
-- an airline is compared only against carriers flying out of the same airport.
-- Only airport-airline pairs with 5,000+ departures are shown.
WITH ap AS (
    SELECT
        f.origin,
        ap.city AS origin_city,
        f.airline_code,
        a.airline_name,
        COUNT(*) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0) AS operated_flights,
        ROUND(100.0 * (1 - AVG(f.arr_del15) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0 AND f.arr_del15 IS NOT NULL)), 2) AS on_time_pct
    FROM flights f
    JOIN airlines a ON a.iata_code = f.airline_code
    JOIN airports ap ON ap.airport = f.origin
    GROUP BY f.origin, ap.city, f.airline_code, a.airline_name
    HAVING COUNT(*) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0) >= 5000
)
SELECT
    origin,
    origin_city,
    airline_code,
    airline_name,
    operated_flights,
    on_time_pct,
    RANK() OVER (PARTITION BY origin ORDER BY on_time_pct DESC) AS rank_within_airport
FROM ap
ORDER BY origin, rank_within_airport;
