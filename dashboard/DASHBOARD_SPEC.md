# Dashboard spec — Power BI / Tableau build

`dashboard/index.html` is the static version of this dashboard (open it in a
browser). To rebuild it as a live Power BI or Tableau dashboard, connect to
the CSVs in this folder — they are the exact outputs of the SQL in `../sql/`.

## Data sources (all in this folder)

| File | Contents | Use |
|---|---|---|
| `02_metrics_q1.csv` | Overall KPIs (1 row) | KPI cards |
| `03_airlines_q1.csv` | On-time %, avg delay, cancellation rate by airline | Airline bar chart |
| `03_airlines_q2.csv` | Airline rank within each origin airport (window function) | Airport detail table |
| `04_airports_q1.csv` | Top 30 airports: traffic, arrival/departure on-time, cancellation rate | Airport table / map |
| `05_time_q1.csv` | On-time % and avg delay by departure hour (0–23) | Hour line chart |
| `05_time_q2.csv` | On-time % by day of week | Weekday bars |
| `05_time_q3.csv` | Monthly on-time %, avg delay, cancellation rate | Seasonality line |
| `06_routes_q1.csv` | Worst 10 routes (1,000+ flights) | Worst-routes table |
| `06_routes_q2.csv` | Best 10 routes (1,000+ flights) | Best-routes table |
| `07_causes_q1.csv` | Delay-minute shares by cause + controllability split | Cause donut / stacked bar |
| `07_causes_q2.csv` | Late-aircraft cascade stats | KPI callout |
| `07_causes_q3.csv` | Late-aircraft share by airline | Airline cascade bars |
| `08_cancellations_q1.csv` | Cancellation rate by airline | Cancellation bars |
| `08_cancellations_q2.csv` | Cancellation rate by month | Cancellation trend |
| `08_cancellations_q3.csv` | Cancellation reasons (carrier / weather / NAS / security) | Reason donut |
| `08_cancellations_q4.csv` | Worst 10 origin airports by cancellation rate | Airport cancellation table |

## Suggested pages

1. **Overview** — KPI cards (on-time %, avg arrival delay, cancellation
   rate, delayed-flight share, controllable share of delay minutes), monthly
   on-time trend, on-time % by departure hour.
2. **Airlines** — on-time % bar chart by airline, cancellation rate by
   airline, late-aircraft share by airline.
3. **Airports & routes** — top-30 airport table (or map), worst-10 and
   best-10 route tables.
4. **Causes** — delay-minute share by cause, controllability split
   (72.7% controllable / 21.2% system / 6.0% weather), cancellation reasons.

## Filters (apply to every page)

- Airline (`airline_code` / `airline_name`)
- Airport (`origin` / `dest`)
- Month (`year`, `month`)

Note: the CSVs are pre-aggregated, so the filters above apply to the
underlying `flights` table in DuckDB (`data/flights.duckdb`), not to these
files. To filter live, connect Power BI / Tableau to the DuckDB database
directly (or re-run `python3 run_analysis.py` with a WHERE clause) and use
the queries in `sql/` as the source.

## Publishing

Publishing to Tableau Public needs the author's own Tableau account and is
not done here. No Power BI (`.pbix`) or Tableau (`.twbx`) file is included
in this repo; the HTML dashboard and the CSVs are the deliverables.
