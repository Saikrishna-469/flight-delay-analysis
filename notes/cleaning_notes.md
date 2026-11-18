# Cleaning notes

## Source
US Bureau of Transportation Statistics (BTS), TranStats, On-Time Performance
table (1987–present). Monthly CSVs, September 2025 – August 2026 (the most
recent 12 months available; September 2026 had not been published when the
data was pulled on 18 Nov 2026). 7,049,869 rows, one per scheduled domestic
flight. Files: `data/raw/*.csv` (git-ignored; see README to reproduce).

Lookup tables: the TranStats `Download_Lookup.asp` endpoint redirects to the
homepage for direct downloads, so the lookup CSVs could not be fetched with
curl. Airport names and cities come straight from the OTP file itself
(`OriginCityName`, `DestCityName`, `OriginState`, `DestState`). Airline full
names are the BTS-published names for the 14 IATA codes present in the data
(`data/airlines.csv`).

## Decisions

1. **Cancelled and diverted flights are kept, but flagged, never mixed into
   delay metrics.** A cancelled flight has no arrival delay, so including it
   would understate delays. Delay metrics use operated flights only
   (`cancelled = 0 AND diverted = 0`). Cancellation rate is measured
   separately on all scheduled flights (133,211 cancelled = 1.89%,
   20,673 diverted = 0.29%).

2. **Scheduled times are HHMM integers.** `CRSDepTime` 5 means 00:05, 2400
   means midnight at the end of the day. `sched_dep_hour` is derived as
   `(CRSDepTime // 100) % 24`, so 2400 maps to hour 0. `DepTimeBlk` /
   `ArrTimeBlk` (e.g. `0800-0859`) are kept as-is for reference.

3. **Delay-cause minutes are NULL when the cause does not apply.** BTS only
   records `CarrierDelay`, `WeatherDelay`, `NASDelay`, `SecurityDelay`, and
   `LateAircraftDelay` for delayed flights. NULL is treated as 0 minutes
   attributed to that cause. QA: only 148 delayed flights (0.01%) have no
   cause minutes at all, and in no case does the sum of causes exceed the
   arrival delay, so the cause breakdown is internally consistent.

4. **One operated flight has a NULL arrival delay** (1 of 6.9M operated
   flights). It is excluded from on-time % by requiring `arr_del15 IS NOT
   NULL`. The effect on any reported number is nil.

5. **"On-time" means arrival delay under 15 minutes** (the BTS `ArrDel15`
   flag: 1 when arrival delay is 15+ minutes). On-time % is computed on
   operated flights only.

6. **Controllable vs uncontrollable split.** Carrier delay and late-aircraft
   delay are treated as airline-controllable; weather is uncontrollable;
   NAS (National Airspace System) and security are system-level. This is a
   judgement call and is stated as such wherever the split is reported.

7. **Airports are identified by IATA code** (`Origin` / `Dest`). The 12
   months cover 360 distinct airport codes. Airport city/state come from
   the most frequent value in the data for that code.

8. **Routes are directional** (`Origin-Dest`), e.g. `JFK-LAX` and `LAX-JFK`
   are different routes. The "worst routes" list requires at least 1,000
   flights so that small-sample routes do not dominate.
