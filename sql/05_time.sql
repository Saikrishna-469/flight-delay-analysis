-- 05_time.sql — Delay by hour of day, day of week, and month.
-- Q4: When do delays happen? (scheduled departure hour, 0–23)
-- Q5: Which days of the week are worst?
-- Q6: Seasonality — which months are worst?
-- Operated flights only.

-- Q4: Delay by scheduled departure hour.
SELECT
    sched_dep_hour,
    COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) AS operated_flights,
    ROUND(100.0 * (1 - AVG(arr_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 IS NOT NULL)), 2) AS on_time_pct,
    ROUND(AVG(arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_arrival_delay_min,
    ROUND(AVG(dep_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_departure_delay_min
FROM flights
WHERE sched_dep_hour IS NOT NULL
GROUP BY sched_dep_hour
ORDER BY sched_dep_hour;

-- Q5: Delay by day of week (BTS: 1 = Monday, 7 = Sunday).
SELECT
    day_of_week,
    CASE day_of_week
        WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday' WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday' END AS weekday,
    COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) AS operated_flights,
    ROUND(100.0 * (1 - AVG(arr_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 IS NOT NULL)), 2) AS on_time_pct,
    ROUND(AVG(arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_arrival_delay_min
FROM flights
GROUP BY day_of_week
ORDER BY day_of_week;

-- Q6: Delay by month (seasonality).
SELECT
    year,
    month,
    COUNT(*) FILTER (WHERE cancelled = 0 AND diverted = 0) AS operated_flights,
    ROUND(100.0 * (1 - AVG(arr_del15) FILTER (WHERE cancelled = 0 AND diverted = 0 AND arr_del15 IS NOT NULL)), 2) AS on_time_pct,
    ROUND(AVG(arr_delay_min) FILTER (WHERE cancelled = 0 AND diverted = 0), 2) AS avg_arrival_delay_min,
    ROUND(100.0 * SUM(cancelled) / COUNT(*), 2) AS cancellation_rate_pct
FROM flights
GROUP BY year, month
ORDER BY year, month;
