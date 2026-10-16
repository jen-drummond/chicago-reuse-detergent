# Chicago Circular: a reusable laundry-jug loop vs. single-use

A **simulated feasibility study**. It asks one question: when does a reusable laundry-detergent jug, collected and washed at a regional hub, beat a single-use jug on waste, carbon and cost, and what has to be true for that to happen?

Nothing here is real operating data. The stores, routes and hub arrangement are modeled. I did not run a pilot, and there is no partnership with TerraCycle, any retailer or any brand. The Aurora, IL operations center is used as a *hypothetical* hub because it is a real, documented reuse-capable site.

- Plain-language write-up: [case-study post](https://becomingcircular.com/your-laundry-jug-should-come-back-modeling-a-reuse-loop-for-chicagoland/)
- Interactive dashboard: [Tableau Public](https://public.tableau.com/views/ChicagoCircularsimulatedreuseloopforlaundryjugs/Sensitivity?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)
- Every assumption, source and limitation: [METHODOLOGY.md](./METHODOLOGY.md)

**Tools:** Python (pandas, NumPy, scikit-learn, SQLAlchemy), PostgreSQL, Tableau Public

---

## What I found

100,000 jugs per scenario, tracked for 18 months (Jan 2026 to Jun 2027), at 90%, 80% and 70% return rates. Base-case assumptions; results are per jug put into circulation.

| | 90% return | 80% return | 70% return |
|---|---|---|---|
| Returns per jug (18 months) | 4.05 | 2.87 | 2.02 |
| **Plastic waste** break-even | month 9 | month 11 | month 18 (barely) |
| **Carbon** break-even | month 13 | not reached | not reached |
| **Cost** break-even | not reached | not reached | not reached |
| Waste at month 18 (kg per jug) | +0.246 | +0.105 | +0.003 |
| Carbon at month 18 (kg CO2e per jug) | +0.161 | -0.009 | -0.132 |
| Cost at month 18 ($ per jug) | -0.395 | -0.513 | -0.598 |

Positive means reuse is ahead of single-use. Negative means single-use is still ahead.

**The honest summary:** in the base case, reuse reduces plastic waste in every scenario, reduces carbon only at a 90% return rate, and does not pay for itself within 18 months. The useful result is *what would have to change*, which the sensitivity analysis maps out:

- **Jug weight decides carbon and waste.** The base case assumes the reusable jug is 3x as heavy as a single-use jug. At 2x, carbon is positive in all three scenarios (months 7, 8 and 10). At 4x, carbon is negative in all three.
- **Cost depends on what a single-use jug costs the brand and how cheaply the loop runs.** At 90% return, with the base reusable-jug price ($1.10) and base wash plus handling ($0.20 per return), cost breaks even within 18 months only if the single-use jug costs at least about $0.38. Alternatively the reusable jug must cost $0.70 or less, or wash plus handling $0.10 or less.
- **Running longer does not fix cost.** With a 10-use design life and a 90% return rate, a jug averages about 5.85 lifetime returns, and the base case needs 8 to be cost-neutral.
- **Return rate matters for every outcome**, and it is the one assumption a program can influence directly.

Across the 81 assumption combinations tested, cost breaks even within 18 months in 63 (90% return), 51 (80%) and 48 (70%). Several of those combinations are optimistic, such as a heavy 4x jug at $0.70, so read the dashboard's break-even map rather than the headline count.

---

## What is in this repo

```
README.md                  this file
docs/METHODOLOGY.md        assumptions, sources, equations, limitations
notebooks/
  route_generator.ipynb                                  50 synthetic stores, 5 routes, route miles
  create_chicago_reuse_data_variable_return_rates.ipynb  simulates jug events, loads PostgreSQL
sql/
  create_schema.sql          tables
  verify_database.sql        checks that the database holds the current data
  reuse_ledger.sql           base-case accounting (every assumption lives in one block)
  check_reuse_ledger.sql     read-only queries to inspect the ledger
  export_for_tableau.sql     base-case summary for Tableau
  sensitivity_for_tableau.sql  re-scores the same events under 81 assumption sets
data/
  stores.csv, routes.csv     small, committed
  (assets.csv and logistics_events.csv are generated and not committed; the events file is ~190 MB)
tableau/
  tableau_reuse_ledger.csv
  tableau_sensitivity_monthly.csv
  tableau_sensitivity_breakeven.csv
```

## How it works, in four steps

1. **Stores and routes.** 50 synthetic store locations are spread across Aurora, Naperville, Evanston, Schaumburg, Oak Park and Lincoln Park in proportion to population, grouped into 5 delivery routes with K-means. Each route's round-trip road miles come from a nearest-neighbour tour from the hub.
2. **Jug lives.** Each jug is bought, used, returned (or lost), washed, and sent out again, for up to 10 uses. Every event is a row. The simulation is seeded, so it reproduces exactly.
3. **The ledger.** SQL scores each event against single-use packaging in three currencies: carbon, plastic waste and dollars. Making a reusable jug is a debt booked on day one. Each return pays some of it back, net of washing and the truck trip. Break-even is the month the running balance turns positive.
4. **Sensitivity.** The same events are re-scored without re-simulating, across jug weight, reusable-jug price, single-use cost and wash plus handling cost.

## Reproducing it

Requires Python 3.10+ and PostgreSQL 16 (other recent versions should work).

```bash
python3 -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r requirements.txt

createdb aurora_reuse_jug_db         # or create it in pgAdmin
psql -d aurora_reuse_jug_db -f sql/create_schema.sql
```

Then, in order:

1. Run `notebooks/route_generator.ipynb` (writes `data/stores.csv` and `data/routes.csv`).
2. Run `notebooks/create_chicago_reuse_data_variable_return_rates.ipynb` (simulates events and loads the database; check the connection string in its database cell).
3. Run `sql/verify_database.sql` and compare with the expected values in its comments.
4. Run `sql/reuse_ledger.sql`, then `sql/export_for_tableau.sql` to produce the base-case CSV.
5. Run `sql/sensitivity_for_tableau.sql`. Its first check should return all zeros, which means the base case in the sensitivity file matches the ledger. Then export its two views to CSV.

The three CSVs in `tableau/` are what the dashboard reads, so you can open the dashboard files without running any of the above.

## Limitations worth knowing before you rely on a number

- The data is synthetic. Results describe how the system behaves under stated assumptions, not what a real rollout would do.
- Several inputs are unsourced assumptions: the reusable jug is 3x the weight of a single-use jug, wash and handling costs, truck emissions per mile, 600 jugs per route run, and the 10-use design life. The sensitivity analysis shows how much each one matters.
- The batch is closed: lost jugs are not replaced and no new jugs are added.
- Producer-responsibility (EPR) fees and deposits are not modeled.
- 100,000 jugs are simulated. The 1 million jugs per year figure is a design target, not a simulated result.

## About

Built by Jen Drummond, PhD, circular-systems and sustainability consultant. [becomingcircular.com](https://becomingcircular.com) · jen@becomingcircular.com