#!/usr/bin/env python3
"""Load BTS On-Time Performance CSVs into DuckDB and run QA checks.

Usage (from the project root):
    python3 load.py

Reads sql/01_load.sql, executes it against data/flights.duckdb, then prints
a QA summary. Raw CSVs live in data/raw/ (git-ignored); the .duckdb file is
also git-ignored — re-run this script to rebuild it.
"""
import duckdb
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DB = ROOT / "data" / "flights.duckdb"
SQL = ROOT / "sql" / "01_load.sql"

con = duckdb.connect(str(DB))
con.execute(SQL.read_text())
print("Loaded tables:", [r[0] for r in con.execute("SHOW TABLES").fetchall()])

qa = {
    "total rows (flights)": "SELECT COUNT(*) FROM flights",
    "date range": "SELECT MIN(flight_date), MAX(flight_date) FROM flights",
    "cancelled flights": "SELECT COUNT(*) FROM flights WHERE cancelled = 1",
    "diverted flights": "SELECT COUNT(*) FROM flights WHERE diverted = 1",
    "distinct airlines": "SELECT COUNT(DISTINCT airline_code) FROM flights",
    "distinct airports": "SELECT COUNT(DISTINCT origin) FROM flights",
    "null ArrDelayMinutes among operated, non-diverted":
        "SELECT COUNT(*) FROM flights WHERE cancelled = 0 AND diverted = 0 AND arr_delay_min IS NULL",
    "delayed flights (ArrDel15=1) with no cause minutes at all":
        "SELECT COUNT(*) FROM flights WHERE arr_del15 = 1 AND "
        "COALESCE(carrier_delay_min,0)+COALESCE(weather_delay_min,0)+COALESCE(nas_delay_min,0)"
        "+COALESCE(security_delay_min,0)+COALESCE(late_aircraft_delay_min,0) = 0",
    "delayed flights where cause minutes sum > arrival delay (data quirk)":
        "SELECT COUNT(*) FROM flights WHERE arr_del15 = 1 AND "
        "COALESCE(carrier_delay_min,0)+COALESCE(weather_delay_min,0)+COALESCE(nas_delay_min,0)"
        "+COALESCE(security_delay_min,0)+COALESCE(late_aircraft_delay_min,0) > arr_delay_min + 1",
}
for label, q in qa.items():
    print(f"- {label}: {con.execute(q).fetchone()}")
con.close()
print("OK")
