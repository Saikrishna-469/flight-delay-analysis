-- 07_causes.sql — What causes delays, and how much is controllable?
-- Q8: Share of delay minutes by cause (carrier, weather, NAS, security,
--     late aircraft), among delayed flights (ArrDel15 = 1).
-- Q9: Cascading delays — how often is "late aircraft" the cause, and how
--     much of all delay time does it explain?
-- Q10: Controllable vs uncontrollable split. Judgement call, documented in
--      notes/cleaning_notes.md: controllable = carrier + late aircraft;
--      system = NAS + security; uncontrollable = weather.

-- Q8 + Q10: Delay minutes by cause and by controllability group.
WITH delayed AS (
    SELECT * FROM flights
    WHERE cancelled = 0 AND diverted = 0 AND arr_del15 = 1
),
totals AS (
    SELECT
        COUNT(*) AS delayed_flights,
        SUM(COALESCE(carrier_delay_min, 0)) AS carrier_min,
        SUM(COALESCE(weather_delay_min, 0)) AS weather_min,
        SUM(COALESCE(nas_delay_min, 0)) AS nas_min,
        SUM(COALESCE(security_delay_min, 0)) AS security_min,
        SUM(COALESCE(late_aircraft_delay_min, 0)) AS late_aircraft_min,
        SUM(arr_delay_min) AS total_arr_delay_min
    FROM delayed
)
SELECT
    delayed_flights,
    ROUND(100.0 * carrier_min / NULLIF(carrier_min + weather_min + nas_min + security_min + late_aircraft_min, 0), 1) AS carrier_share_pct,
    ROUND(100.0 * late_aircraft_min / NULLIF(carrier_min + weather_min + nas_min + security_min + late_aircraft_min, 0), 1) AS late_aircraft_share_pct,
    ROUND(100.0 * nas_min / NULLIF(carrier_min + weather_min + nas_min + security_min + late_aircraft_min, 0), 1) AS nas_share_pct,
    ROUND(100.0 * weather_min / NULLIF(carrier_min + weather_min + nas_min + security_min + late_aircraft_min, 0), 1) AS weather_share_pct,
    ROUND(100.0 * security_min / NULLIF(carrier_min + weather_min + nas_min + security_min + late_aircraft_min, 0), 1) AS security_share_pct,
    ROUND(100.0 * (carrier_min + late_aircraft_min) / NULLIF(carrier_min + weather_min + nas_min + security_min + late_aircraft_min, 0), 1) AS controllable_share_pct,
    ROUND(100.0 * (nas_min + security_min) / NULLIF(carrier_min + weather_min + nas_min + security_min + late_aircraft_min, 0), 1) AS system_share_pct,
    ROUND(total_arr_delay_min / 60.0 / 1000, 1) AS total_delay_thousand_hours
FROM totals;

-- Q9: Cascading delays — late aircraft as a cause.
-- (a) Of all delayed flights, how many had ANY late-aircraft minutes?
-- (b) Of all delayed flights, how many had late aircraft as the LARGEST cause?
-- (c) Late-aircraft share by airline (which carriers cascade most?).
SELECT
    COUNT(*) AS delayed_flights,
    SUM(CASE WHEN COALESCE(late_aircraft_delay_min, 0) > 0 THEN 1 ELSE 0 END) AS with_late_aircraft_min,
    ROUND(100.0 * SUM(CASE WHEN COALESCE(late_aircraft_delay_min, 0) > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_delayed_with_late_aircraft,
    SUM(CASE WHEN COALESCE(late_aircraft_delay_min, 0) >= GREATEST(COALESCE(carrier_delay_min, 0), COALESCE(weather_delay_min, 0), COALESCE(nas_delay_min, 0), COALESCE(security_delay_min, 0)) AND COALESCE(late_aircraft_delay_min, 0) > 0 THEN 1 ELSE 0 END) AS late_aircraft_largest_cause,
    ROUND(100.0 * SUM(CASE WHEN COALESCE(late_aircraft_delay_min, 0) >= GREATEST(COALESCE(carrier_delay_min, 0), COALESCE(weather_delay_min, 0), COALESCE(nas_delay_min, 0), COALESCE(security_delay_min, 0)) AND COALESCE(late_aircraft_delay_min, 0) > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_delayed_where_late_aircraft_largest
FROM flights
WHERE cancelled = 0 AND diverted = 0 AND arr_del15 = 1;

-- (c) Late-aircraft share of delay minutes, by airline.
SELECT
    f.airline_code,
    a.airline_name,
    COUNT(*) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0 AND f.arr_del15 = 1) AS delayed_flights,
    ROUND(100.0 * SUM(COALESCE(f.late_aircraft_delay_min, 0)) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0 AND f.arr_del15 = 1)
        / NULLIF(SUM(COALESCE(f.carrier_delay_min, 0) + COALESCE(f.weather_delay_min, 0) + COALESCE(f.nas_delay_min, 0) + COALESCE(f.security_delay_min, 0) + COALESCE(f.late_aircraft_delay_min, 0)) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0 AND f.arr_del15 = 1), 0), 1) AS late_aircraft_share_of_delay_min_pct,
    ROUND(100.0 * SUM(COALESCE(f.carrier_delay_min, 0)) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0 AND f.arr_del15 = 1)
        / NULLIF(SUM(COALESCE(f.carrier_delay_min, 0) + COALESCE(f.weather_delay_min, 0) + COALESCE(f.nas_delay_min, 0) + COALESCE(f.security_delay_min, 0) + COALESCE(f.late_aircraft_delay_min, 0)) FILTER (WHERE f.cancelled = 0 AND f.diverted = 0 AND f.arr_del15 = 1), 0), 1) AS carrier_share_of_delay_min_pct
FROM flights f
JOIN airlines a ON a.iata_code = f.airline_code
GROUP BY f.airline_code, a.airline_name
ORDER BY late_aircraft_share_of_delay_min_pct DESC;
