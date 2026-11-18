-- 08_cancellations.sql — Cancellations: who, where, when, and why.
-- Cancellation rate is measured on ALL scheduled flights (a cancelled
-- flight is a scheduled flight that did not operate).
-- CancellationCode: A = carrier, B = weather, C = NAS, D = security.

-- Cancellation rate by airline.
SELECT
    f.airline_code,
    a.airline_name,
    COUNT(*) AS scheduled_flights,
    SUM(f.cancelled) AS cancelled_flights,
    ROUND(100.0 * SUM(f.cancelled) / COUNT(*), 2) AS cancellation_rate_pct
FROM flights f
JOIN airlines a ON a.iata_code = f.airline_code
GROUP BY f.airline_code, a.airline_name
ORDER BY cancellation_rate_pct DESC;

-- Cancellation rate by month.
SELECT
    year,
    month,
    COUNT(*) AS scheduled_flights,
    SUM(cancelled) AS cancelled_flights,
    ROUND(100.0 * SUM(cancelled) / COUNT(*), 2) AS cancellation_rate_pct
FROM flights
GROUP BY year, month
ORDER BY year, month;

-- Cancellation reason codes (share of all cancellations).
SELECT
    cancellation_code,
    CASE cancellation_code
        WHEN 'A' THEN 'Carrier'
        WHEN 'B' THEN 'Weather'
        WHEN 'C' THEN 'National Airspace System'
        WHEN 'D' THEN 'Security'
        ELSE 'Unknown' END AS reason,
    COUNT(*) AS cancellations,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM flights
WHERE cancelled = 1
GROUP BY cancellation_code
ORDER BY cancellations DESC;

-- Worst 10 origin airports by cancellation rate (5,000+ scheduled departures).
SELECT
    f.origin AS airport,
    ap.city,
    COUNT(*) AS scheduled_departures,
    SUM(f.cancelled) AS cancelled_departures,
    ROUND(100.0 * SUM(f.cancelled) / COUNT(*), 2) AS cancellation_rate_pct
FROM flights f
JOIN airports ap ON ap.airport = f.origin
GROUP BY f.origin, ap.city
HAVING COUNT(*) >= 5000
ORDER BY cancellation_rate_pct DESC
LIMIT 10;
