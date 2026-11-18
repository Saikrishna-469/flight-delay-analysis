-- 02_metrics.sql — Overall KPIs, Sep 2025 – Aug 2026.
-- Operated flights = not cancelled and not diverted.
-- On-time = arrival delay under 15 minutes (ArrDel15 = 0).

WITH base AS (
    SELECT * FROM flights
)
SELECT
    COUNT(*) AS total_scheduled_flights,
    SUM(cancelled) AS cancelled_flights,
    ROUND(100.0 * SUM(cancelled) / COUNT(*), 2) AS cancellation_rate_pct,
    SUM(diverted) AS diverted_flights,
    COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) AS operated_flights,
    ROUND(100.0 * (1 - AVG(arr_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 IS NOT NULL)), 2) AS on_time_pct,
    ROUND(100.0 * AVG(arr_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 IS NOT NULL), 2) AS delayed_15plus_pct,
    ROUND(AVG(arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_arrival_delay_min,
    ROUND(AVG(dep_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_departure_delay_min,
    ROUND(AVG(arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 = 1), 1) AS avg_delay_min_when_delayed,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 1) AS median_arrival_delay_min,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 1) AS p95_arrival_delay_min
FROM base;
