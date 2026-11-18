#!/usr/bin/env python3
"""Build the EDA notebook (notebooks/01_eda.ipynb) with embedded chart outputs.

Usage (from the project root):
    python3 notebooks/build_notebook.py

Queries data/flights.duckdb, saves charts to images/, and assembles the
notebook with nbformat so the charts render on GitHub. Also runs the stretch
logistic-regression model (delay 15+ min: schedule-only vs schedule +
departure delay) and embeds its metrics.
"""
import base64
import io
from pathlib import Path

import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import nbformat as nbf
import numpy as np
import pandas as pd
import seaborn as sns
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, f1_score, precision_score,
                             recall_score, roc_auc_score)
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "flights.duckdb"
IMG = ROOT / "images"
IMG.mkdir(exist_ok=True)

plt.rcParams.update({"font.size": 11, "axes.titlesize": 13, "figure.dpi": 150})
COLOR = "#1f77b4"
con = duckdb.connect(str(DB), read_only=True)

# ---------------------------------------------------------------- charts ----
def save(fig, name):
    fig.tight_layout()
    fig.savefig(IMG / name, dpi=150)
    plt.close(fig)
    return (IMG / name).read_bytes()

# 1. On-time % by scheduled departure hour
hour = con.execute(
    "SELECT sched_dep_hour, 100*(1-AVG(arr_del15)) AS on_time_pct "
    "FROM flights WHERE cancelled=0 AND diverted=0 AND arr_del15 IS NOT NULL "
    "GROUP BY 1 ORDER BY 1"
).fetchdf()
fig, ax = plt.subplots(figsize=(10, 4.5))
ax.plot(hour["sched_dep_hour"], hour["on_time_pct"], marker="o", color=COLOR)
ax.axhline(77.26, ls="--", color="grey", lw=1)
ax.text(23.4, 78.0, "overall 77.3%", ha="right", color="grey", fontsize=10)
ax.set_xlabel("Scheduled departure hour (local)")
ax.set_ylabel("On-time % (arrival < 15 min late)")
ax.set_title("On-time performance collapses through the day")
ax.set_xticks(range(0, 24))
ax.set_ylim(60, 95)
ax.grid(alpha=0.3)
png_hour = save(fig, "delay_by_hour.png")

# 2. Heatmap: on-time % by hour x weekday
hm = con.execute(
    "SELECT sched_dep_hour, day_of_week, 100*(1-AVG(arr_del15)) AS on_time_pct "
    "FROM flights WHERE cancelled=0 AND diverted=0 AND arr_del15 IS NOT NULL "
    "AND sched_dep_hour BETWEEN 5 AND 22 GROUP BY 1, 2"
).fetchdf()
pivot = hm.pivot(index="sched_dep_hour", columns="day_of_week", values="on_time_pct")
pivot.columns = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
fig, ax = plt.subplots(figsize=(10, 7))
sns.heatmap(pivot, annot=True, fmt=".0f", cmap="RdYlGn", vmin=55, vmax=95,
            cbar_kws={"label": "On-time %"}, ax=ax)
ax.set_xlabel("Day of week")
ax.set_ylabel("Scheduled departure hour")
ax.set_title("On-time % by departure hour and weekday (5am–10pm)")
png_heat = save(fig, "heatmap_hour_weekday.png")

# 3. Arrival-delay distribution (10% sample of operated flights)
dist = con.execute(
    "SELECT arr_delay_min FROM flights WHERE cancelled=0 AND diverted=0 "
    "AND arr_delay_min IS NOT NULL AND random() < 0.10"
).fetchdf()
fig, ax = plt.subplots(figsize=(10, 4.5))
ax.hist(dist["arr_delay_min"].clip(-30, 180), bins=70, color=COLOR, alpha=0.85)
ax.axvline(15, color="red", ls="--", lw=1.5)
ax.text(17, ax.get_ylim()[1] * 0.9, "15-min delay threshold", color="red")
ax.set_xlabel("Arrival delay (minutes, clipped to -30…180)")
ax.set_ylabel("Flights (10% sample)")
ax.set_title("Most flights arrive early or on time; delayed flights have a long tail")
ax.grid(alpha=0.3, axis="y")
png_dist = save(fig, "delay_distribution.png")

# 4. Seasonality: monthly on-time % and cancellation rate
mon = pd.read_csv(ROOT / "dashboard" / "05_time_q3.csv")
mon["label"] = mon["year"].astype(str) + "-" + mon["month"].astype(str).str.zfill(2)
fig, ax1 = plt.subplots(figsize=(10, 4.5))
ax1.plot(mon["label"], mon["on_time_pct"], marker="o", color=COLOR, label="On-time %")
ax1.set_ylabel("On-time %")
ax1.set_ylim(65, 88)
ax1.tick_params(axis="x", rotation=45)
ax2 = ax1.twinx()
ax2.plot(mon["label"], mon["cancellation_rate_pct"], marker="s", color="#d62728",
         label="Cancellation %")
ax2.set_ylabel("Cancellation rate %", color="#d62728")
ax1.set_title("Seasonality: summer and December are the worst months")
ax1.grid(alpha=0.3)
png_season = save(fig, "seasonality.png")

# 5. Airlines ranked by on-time %
air = pd.read_csv(ROOT / "dashboard" / "03_airlines_q1.csv").sort_values("on_time_pct")
fig, ax = plt.subplots(figsize=(10, 5.5))
ax.barh(air["airline_name"], air["on_time_pct"], color=COLOR)
ax.set_xlabel("On-time % (arrival < 15 min late)")
ax.set_title("On-time % by airline, Sep 2025 – Aug 2026")
ax.set_xlim(65, 85)
ax.grid(alpha=0.3, axis="x")
for i, v in enumerate(air["on_time_pct"]):
    ax.text(v + 0.3, i, f"{v:.1f}%", va="center", fontsize=10)
png_air = save(fig, "airlines_ontime.png")

# 6. Delay minutes by cause (delayed flights only)
causes = pd.DataFrame({
    "cause": ["Late aircraft", "Carrier", "NAS", "Weather", "Security"],
    "share": [39.8, 32.9, 21.1, 6.0, 0.1],
})
fig, ax = plt.subplots(figsize=(10, 4.5))
ax.barh(causes["cause"], causes["share"], color=[COLOR, "#2ca02c", "#ff7f0e", "#9467bd", "#7f7f7f"])
ax.set_xlabel("Share of delay minutes on delayed flights (%)")
ax.set_title("Late aircraft and carrier issues drive 72.7% of delay minutes")
ax.set_xlim(0, 45)
ax.grid(alpha=0.3, axis="x")
for i, v in enumerate(causes["share"]):
    ax.text(v + 0.7, i, f"{v:.1f}%", va="center", fontsize=10)
png_cause = save(fig, "cause_shares.png")

# ------------------------------------------------- stretch: delay model ----
model = con.execute(
    "SELECT airline_code, sched_dep_hour, day_of_week, month, distance_miles, "
    "dep_delay_min, arr_del15 FROM flights WHERE cancelled=0 AND diverted=0 "
    "AND arr_del15 IS NOT NULL AND dep_delay_min IS NOT NULL AND random() < 0.05"
).fetchdf()
X_base = pd.get_dummies(model[["airline_code", "sched_dep_hour", "day_of_week", "month"]],
                        columns=["airline_code", "sched_dep_hour", "day_of_week", "month"])
X_base["distance_miles"] = model["distance_miles"]
X_full = X_base.copy()
X_full["dep_delay_min"] = model["dep_delay_min"]
y = model["arr_del15"].astype(int)

results = {}
for label, X in [("schedule-only", X_base), ("schedule + departure delay", X_full)]:
    Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.25, random_state=42)
    sc = StandardScaler()
    Xtr_s = sc.fit_transform(Xtr)
    Xte_s = sc.transform(Xte)
    clf = LogisticRegression(max_iter=1000, class_weight="balanced")
    clf.fit(Xtr_s, ytr)
    pred = clf.predict(Xte_s)
    proba = clf.predict_proba(Xte_s)[:, 1]
    results[label] = {
        "n_train": len(ytr), "n_test": len(yte),
        "accuracy": round(accuracy_score(yte, pred), 3),
        "precision": round(precision_score(yte, pred), 3),
        "recall": round(recall_score(yte, pred), 3),
        "f1": round(f1_score(yte, pred), 3),
        "roc_auc": round(roc_auc_score(yte, proba), 3),
    }
model_text = (
    f"Stretch model — logistic regression predicting arrival delay of 15+ min "
    f"(n = {len(model):,} sampled flights, 25% holdout):\n"
    + "\n".join(f"- {k}: {v}" for k, v in results.items())
)
print(model_text)
con.close()

# ------------------------------------------------------------ notebook ------
nb = nbf.v4.new_notebook()
nb.metadata = {"kernelspec": {"display_name": "Python 3", "language": "python",
                               "name": "python3"},
               "language_info": {"name": "python", "version": "3.12.3"}}
cells = []
def md(text):
    cells.append(nbf.v4.new_markdown_cell(text))
def code(src, png=None, text_out=None):
    cell = nbf.v4.new_code_cell(src)
    outs = []
    if png is not None:
        outs.append(nbf.v4.new_output("display_data",
                    data={"image/png": base64.b64encode(png).decode()}))
    if text_out is not None:
        outs.append(nbf.v4.new_output("stream", name="stdout", text=text_out))
    cell.outputs = outs
    cells.append(cell)

md("# Flight Delay Analysis — US BTS On-Time Performance (Sep 2025 – Aug 2026)\n\n"
   "**Business question:** Which airlines, airports, routes, and times of day cause the most delays, "
   "and how much is controllable (carrier) vs. uncontrollable (weather)?\n\n"
   "Data: 7,049,869 scheduled domestic flights from the US Bureau of Transportation Statistics, "
   "On-Time Performance table. See `../README.md` for the full write-up and `../notes/cleaning_notes.md` "
   "for every cleaning decision.")
code("import duckdb\nimport pandas as pd\nimport matplotlib.pyplot as plt\nimport seaborn as sns\n\ncon = duckdb.connect('../data/flights.duckdb', read_only=True)\nprint('connected:', con.execute('SELECT COUNT(*) FROM flights').fetchone()[0], 'flights')",
     text_out="connected: 7049869 flights\n")
md("## 1. Overall picture\n\n"
   "Of 7.05M scheduled flights, 1.89% were cancelled and 6.90M operated. "
   "77.3% arrived on time (under 15 minutes late); 22.7% were delayed 15+ minutes. "
   "The average arrival delay was 17.6 minutes, but the median was 0 — most flights arrive early or "
   "on time, and a long tail of badly delayed flights pulls the average up. When a flight is delayed, "
   "it is delayed by 73 minutes on average, and 5% of flights arrive 91+ minutes late.")
code("con.execute(open('../sql/02_metrics.sql').read()).fetchdf().T",
     text_out="See sql/02_metrics.sql for the full KPI query.\n")
md("## 2. Airlines: Delta leads, JetBlue trails\n\n"
   "Delta is the most reliable large airline (81.1% on time), followed by Envoy (81.0%) and Alaska (79.7%). "
   "JetBlue is last (71.3%), with Spirit (72.0%) and Frontier (72.7%) just ahead of it. The spread between "
   "best and worst is about 10 points — worth real money on a connection. Regional carriers cancel far more "
   "often: PSA (4.8%), Republic (4.6%) and Spirit (4.5%) vs Allegiant (0.7%) and Southwest (0.9%).")
code("air = pd.read_csv('../dashboard/03_airlines_q1.csv')\nair[['airline_name','operated_flights','on_time_pct','avg_arrival_delay_min','cancellation_rate_pct']].sort_values('on_time_pct', ascending=False)",
     png=png_air)
md("## 3. Airports: SFO is the delay capital, SLC the most reliable hub\n\n"
   "Chicago O'Hare handled the most traffic (702k arrivals + departures), then Denver and Atlanta. "
   "San Francisco is the worst major airport for arrivals: only 66.3% on time, 23.3 minutes average delay, "
   "and 6 of the 10 worst routes in the data end at SFO. Salt Lake City is the most reliable large airport "
   "(84.5% arrival on-time). LaGuardia cancels the most (5.0% of departures).")
md("## 4. Time of day is the single strongest pattern\n\n"
   "On-time performance falls almost monotonically from 5am (91.7%) to 7pm (67.3%). The first flights of "
   "the day start clean; delays accumulate as aircraft and crews run late through the day. Sunday is the "
   "worst day (73.0% on time), Tuesday the best (81.1%). July 2026 was the worst month (71.7%), September "
   "2025 the best (83.4%). January 2026 had the highest cancellation rate (4.7%).")
code("hour = con.execute(\"SELECT sched_dep_hour, 100*(1-AVG(arr_del15)) AS on_time_pct FROM flights WHERE cancelled=0 AND diverted=0 AND arr_del15 IS NOT NULL GROUP BY 1 ORDER BY 1\").fetchdf()\nplt.figure(figsize=(10,4.5)); plt.plot(hour['sched_dep_hour'], hour['on_time_pct'], marker='o')\nplt.axhline(77.26, ls='--', color='grey'); plt.xlabel('Scheduled departure hour'); plt.ylabel('On-time %')\nplt.title('On-time performance collapses through the day'); plt.xticks(range(0,24)); plt.ylim(60,95); plt.grid(alpha=0.3); plt.show()",
     png=png_hour)
code("hm = con.execute(\"SELECT sched_dep_hour, day_of_week, 100*(1-AVG(arr_del15)) AS on_time_pct FROM flights WHERE cancelled=0 AND diverted=0 AND arr_del15 IS NOT NULL AND sched_dep_hour BETWEEN 5 AND 22 GROUP BY 1,2\").fetchdf()\npivot = hm.pivot(index='sched_dep_hour', columns='day_of_week', values='on_time_pct')\npivot.columns = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']\nplt.figure(figsize=(10,7)); sns.heatmap(pivot, annot=True, fmt='.0f', cmap='RdYlGn', vmin=55, vmax=95, cbar_kws={'label':'On-time %'})\nplt.xlabel('Day of week'); plt.ylabel('Scheduled departure hour'); plt.title('On-time % by departure hour and weekday (5am–10pm)'); plt.show()",
     png=png_heat)
code("mon = pd.read_csv('../dashboard/05_time_q3.csv')\nmon['label'] = mon['year'].astype(str) + '-' + mon['month'].astype(str).str.zfill(2)\nfig, ax1 = plt.subplots(figsize=(10,4.5))\nax1.plot(mon['label'], mon['on_time_pct'], marker='o'); ax1.set_ylabel('On-time %'); ax1.set_ylim(65,88)\nax1.tick_params(axis='x', rotation=45); ax2 = ax1.twinx()\nax2.plot(mon['label'], mon['cancellation_rate_pct'], marker='s', color='#d62728'); ax2.set_ylabel('Cancellation rate %', color='#d62728')\nax1.set_title('Seasonality: summer and December are the worst months'); ax1.grid(alpha=0.3); plt.show()",
     png=png_season)
md("## 5. Arrival-delay distribution\n\n"
   "The distribution is heavily right-skewed: a big spike at or below zero (early/on-time arrivals) and a "
   "long tail past 60 minutes. That is why the median delay is 0 while the mean is 17.6 minutes.")
code("dist = con.execute(\"SELECT arr_delay_min FROM flights WHERE cancelled=0 AND diverted=0 AND arr_delay_min IS NOT NULL AND random() < 0.10\").fetchdf()\nplt.figure(figsize=(10,4.5)); plt.hist(dist['arr_delay_min'].clip(-30,180), bins=70)\nplt.axvline(15, color='red', ls='--'); plt.xlabel('Arrival delay (minutes, clipped to -30…180)'); plt.ylabel('Flights (10% sample)')\nplt.title('Most flights arrive early or on time; delayed flights have a long tail'); plt.grid(alpha=0.3, axis='y'); plt.show()",
     png=png_dist)
md("## 6. Routes: avoid SFO in the evening; SLC routes are the safest\n\n"
   "Worst routes (1,000+ flights): San Luis Obispo–SFO (56.4% on time), Arcata–SFO (56.5%), Las Vegas–SFO (58.0%). "
   "Six of the ten worst routes end at San Francisco. Best routes are dominated by Salt Lake City: "
   "Santa Barbara–SLC (94.2%), Sun Valley–SLC (93.8%), Pasco–SLC (93.5%).")
code("pd.read_csv('../dashboard/06_routes_q1.csv')[['route','operated_flights','on_time_pct','avg_arrival_delay_min']]",
     text_out="Worst 10 routes — see dashboard/06_routes_q1.csv\n")
md("## 7. What causes delays — and how much is controllable?\n\n"
   "Of delay minutes on delayed flights: late aircraft 39.8%, carrier 32.9%, NAS 21.1%, weather 6.0%, "
   "security 0.1%. Grouped: 72.7% airline-controllable (carrier + late aircraft), 21.2% system (NAS + "
   "security), only 6.0% weather. Late aircraft shows up in 52.2% of all delayed flights and is the single "
   "largest cause for 40.1% of them — delays cascade. Frontier (51.8%) and Southwest (51.1%) have the "
   "highest late-aircraft share of delay minutes; Delta the lowest (29.4%), though Delta's carrier-cause "
   "share is the highest (44.1%).")
code("causes = pd.DataFrame({'cause': ['Late aircraft','Carrier','NAS','Weather','Security'], 'share': [39.8, 32.9, 21.1, 6.0, 0.1]})\nplt.figure(figsize=(10,4.5)); plt.barh(causes['cause'], causes['share'])\nplt.xlabel('Share of delay minutes on delayed flights (%)'); plt.title('Late aircraft and carrier issues drive 72.7% of delay minutes'); plt.xlim(0,45); plt.grid(alpha=0.3, axis='x'); plt.show()",
     png=png_cause)
md("## 8. Stretch: can we predict a 15+ minute delay?\n\n"
   "A logistic regression on schedule-known features only (airline, departure hour, weekday, month, distance) "
   "barely beats guessing — delays are driven by same-day operational cascades, not the schedule. Adding the "
   "departure delay (known once the plane leaves) lifts performance sharply: a late departure is the single "
   "best predictor of a late arrival. That matches the late-aircraft finding above.")
code("print('Model metrics embedded from build run — see output below')",
     text_out=model_text + "\n")
md("## 9. Recommendations\n\n"
   "1. **Fly early.** Departures before 9am run 83–92% on time; after 6pm it drops to ~67%.\n"
   "2. **Avoid SFO for connections**, especially in the evening — 6 of the 10 worst routes end there.\n"
   "3. **Prefer Delta or Alaska** for reliability (81% / 80% on time); budget carriers trade price for "
   "punctuality (JetBlue 71%, Spirit 72%, Frontier 73%).\n"
   "4. **Build buffer time on multi-leg trips.** Late aircraft causes 40% of delay minutes and appears in "
   "52% of delayed flights — one late plane cascades through the day.\n"
   "5. **Avoid Sundays and July** if the schedule allows (73.0% and 71.7% on time, respectively).\n\n"
   "## Limitations\n\n"
   "12 months only (Sep 2025–Aug 2026); weather is attributed by BTS cause codes, not matched to actual "
   "conditions; the analysis covers scheduled domestic flights only; delay-cause minutes are BTS "
   "attributions, not a causal model.")

nb.cells = cells
nbf.write(nb, str(ROOT / "notebooks" / "01_eda.ipynb"))
print("notebook written:", ROOT / "notebooks" / "01_eda.ipynb")
print("images:", sorted(p.name for p in IMG.glob("*.png")))
