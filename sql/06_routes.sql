-- 06_routes.sql — Worst (and best) routes.
-- Q7: Which routes are the least reliable? Routes are directional
--     (JFK-LAX differs from LAX-JFK). Only routes with 1,000+ operated
--     flights are ranked, so small-sample routes do not dominate.

WITH routes AS (
    SELECT
        origin,
        dest,
        origin || '-' || dest AS route,
        COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) AS operated_flights,
        ROUND(100.0 * (1 - AVG(arr_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 IS NOT NULL)), 2) AS on_time_pct,
        ROUND(AVG(arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_arrival_delay_min
    FROM flights
    GROUP BY origin, dest
    HAVING COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) >= 1000
)
SELECT
    route,
    operated_flights,
    on_time_pct,
    avg_arrival_delay_min,
    RANK() OVER (ORDER BY on_time_pct ASC) AS worst_rank
FROM routes
ORDER BY on_time_pct ASC
LIMIT 10;

-- Best 10 routes for contrast (same 1,000-flight minimum).
WITH routes AS (
    SELECT
        origin,
        dest,
        origin || '-' || dest AS route,
        COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) AS operated_flights,
        ROUND(100.0 * (1 - AVG(arr_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 IS NOT NULL)), 2) AS on_time_pct,
        ROUND(AVG(arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_arrival_delay_min
    FROM flights
    GROUP BY origin, dest
    HAVING COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) >= 1000
)
SELECT
    route,
    operated_flights,
    on_time_pct,
    avg_arrival_delay_min,
    RANK() OVER (ORDER BY on_time_pct DESC) AS best_rank
FROM routes
ORDER BY on_time_pct DESC
LIMIT 10;
