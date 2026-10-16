/* ======================================================================
   SENSITIVITY ANALYSIS FOR TABLEAU
   Re-scores the SAME simulated events under many different assumptions, to answer:
   "Which assumptions does the result depend on, and what has to be true for reuse to break even?"

   No new simulation is needed. The simulation decides WHEN jugs are made and returned.
   The assumptions below only change how much each of those events is worth, so we can
   re-score the events as many times as we like.

   WHAT IS VARIED (3 values each, 81 combinations, called "cases")
     weight_multiple     reusable jug weight as a multiple of the single-use jug (2x, 3x, 4x)
     jug_cost            what one reusable jug costs ($0.70, $0.90, $1.10)
     avoided_cost        packaging cost avoided each time a refill replaces a single-use jug ($0.30, $0.45, $0.60)
     wash_handling_cost  wash + handling cost per return ($0.10, $0.20, $0.30)
   The return rate (70 / 80 / 90%) is already in the data as the "scenario" column.

   BASE CASE (matches reuse_ledger.sql): 3x, $1.10, $0.30, $0.20.

   WHAT IS HELD FIXED (same values as reuse_ledger.sql; change both files together):
     single-use jug 0.120 kg, HDPE 1.73 kg CO2e/kg, landfill 0.044 kg CO2e/kg, wash 0.030 kg CO2e.
     Truck emissions come from the reuse_ledger view (route-specific), so they are not repeated here.

   LIMITATION: the four inputs are varied independently. In reality a heavier jug would cost more,
   so combinations such as 4x weight at $0.70 are not realistic. Filter them out in Tableau.

   RUN to create the two views, then run CHECK 1, then export each view to a CSV (bottom of file).
   Re-running is safe: the two DROP lines remove the old versions first. (CREATE OR REPLACE alone
   fails if a column's data type changes.)
   ====================================================================== */

DROP VIEW IF EXISTS sensitivity_breakeven;   -- first, because it is built on sensitivity_monthly
DROP VIEW IF EXISTS sensitivity_monthly;

-- VIEW 1: month-by-month running totals per jug, for every case and every return-rate scenario
CREATE VIEW sensitivity_monthly AS
WITH monthly_counts AS (               -- the events, added up by scenario and month
    SELECT scenario,
           month_date::date            AS month_date,
           SUM(is_manufactured)        AS manufactured,
           SUM(is_returned)            AS returned,
           SUM(event_logistics_carbon) AS logistics_carbon_kg   -- already negative, and specific to each route
    FROM reuse_ledger
    GROUP BY scenario, month_date
),
fixed AS (
    SELECT 0.120 AS single_use_kg,
           1.73  AS resin_kgco2e_per_kg,
           0.044 AS landfill_kgco2e_per_kg,
           0.030 AS wash_kgco2e
),
cases AS (                             -- every combination of the four varied inputs: 3 x 3 x 3 x 3 = 81
    SELECT w.weight_multiple, j.jug_cost, a.avoided_cost, h.wash_handling_cost
    FROM (VALUES (2), (3), (4))                 AS w(weight_multiple)
    CROSS JOIN (VALUES (0.70), (0.90), (1.10))  AS j(jug_cost)
    CROSS JOIN (VALUES (0.30), (0.45), (0.60))  AS a(avoided_cost)
    CROSS JOIN (VALUES (0.10), (0.20), (0.30))  AS h(wash_handling_cost)
),
scored AS (                            -- value of each month's events under each case
    SELECT c.weight_multiple, c.jug_cost, c.avoided_cost, c.wash_handling_cost,
           m.scenario, m.month_date, m.manufactured, m.returned,
           -- carbon: extra plastic made (booked at manufacture) + avoided single-use jug and wash on each return + truck share
           m.manufactured * f.single_use_kg * (1 - c.weight_multiple) * (f.resin_kgco2e_per_kg + f.landfill_kgco2e_per_kg)
           + m.returned * (f.single_use_kg * (f.resin_kgco2e_per_kg + f.landfill_kgco2e_per_kg) - f.wash_kgco2e)
           + m.logistics_carbon_kg                                              AS carbon_kg,
           -- waste: extra plastic of the reusable jug, minus the single-use jug avoided on each return
           m.manufactured * f.single_use_kg * (1 - c.weight_multiple)
           + m.returned * f.single_use_kg                                       AS waste_kg,
           -- dollars: first fill avoids one single-use packaging cost but the jug is bought; each return avoids packaging, pays wash + handling
           m.manufactured * (c.avoided_cost - c.jug_cost)
           + m.returned * (c.avoided_cost - c.wash_handling_cost)               AS dollars
    FROM monthly_counts m
    CROSS JOIN cases c
    CROSS JOIN fixed f
),
running AS (                           -- running totals over time, per case and scenario
    SELECT s.*,
           ROW_NUMBER() OVER w                                                  AS month_number,
           SUM(returned)  OVER w                                                AS returns_so_far,
           SUM(carbon_kg) OVER w                                                AS carbon_so_far,
           SUM(waste_kg)  OVER w                                                AS waste_so_far,
           SUM(dollars)   OVER w                                                AS dollars_so_far,
           SUM(manufactured) OVER (PARTITION BY weight_multiple, jug_cost, avoided_cost, wash_handling_cost, scenario) AS jugs
    FROM scored s
    WINDOW w AS (PARTITION BY weight_multiple, jug_cost, avoided_cost, wash_handling_cost, scenario ORDER BY month_date)
)
SELECT weight_multiple,
       ROUND(0.120 * 1000 * weight_multiple)                    AS reusable_jug_grams,
       jug_cost, avoided_cost, wash_handling_cost,
       (weight_multiple = 3 AND jug_cost = 1.10 AND avoided_cost = 0.30 AND wash_handling_cost = 0.20)::int AS is_base_case,  -- 1 = base case, 0 = a variation
       scenario,
       month_number,
       month_date,
       ROUND((returns_so_far / jugs)::numeric, 3)               AS returns_per_jug_so_far,
       ROUND((carbon_so_far  / jugs)::numeric, 4)               AS carbon_kg_per_jug_so_far,
       ROUND((waste_so_far   / jugs)::numeric, 4)               AS waste_kg_per_jug_so_far,
       ROUND((dollars_so_far / jugs)::numeric, 4)               AS dollars_per_jug_so_far
FROM running;

-- VIEW 2: one row per case and scenario: the month each result first turns positive (blank = not within the study period)
CREATE VIEW sensitivity_breakeven AS
SELECT weight_multiple, reusable_jug_grams, jug_cost, avoided_cost, wash_handling_cost, is_base_case, scenario,
       MIN(month_number) FILTER (WHERE carbon_kg_per_jug_so_far >= 0)  AS carbon_breakeven_month,
       MIN(month_number) FILTER (WHERE waste_kg_per_jug_so_far  >= 0)  AS waste_breakeven_month,
       MIN(month_number) FILTER (WHERE dollars_per_jug_so_far   >= 0)  AS cost_breakeven_month,
       MAX(month_number)                                               AS months_in_study,
       (ARRAY_AGG(carbon_kg_per_jug_so_far ORDER BY month_number DESC))[1] AS carbon_kg_per_jug_at_end,
       (ARRAY_AGG(waste_kg_per_jug_so_far  ORDER BY month_number DESC))[1] AS waste_kg_per_jug_at_end,
       (ARRAY_AGG(dollars_per_jug_so_far   ORDER BY month_number DESC))[1] AS dollars_per_jug_at_end
FROM sensitivity_monthly
GROUP BY weight_multiple, reusable_jug_grams, jug_cost, avoided_cost, wash_handling_cost, is_base_case, scenario;

-- ------------------------------------------------------------------
-- CHECK 1 (run this): the base case here must match the main ledger exactly. Every "diff" column should be 0.
SELECT s.scenario,
       ROUND(s.carbon_kg_per_jug_at_end::numeric - (SUM(l.event_carbon_impact)   / SUM(l.is_manufactured))::numeric, 4) AS carbon_diff,
       ROUND(s.waste_kg_per_jug_at_end::numeric  - (SUM(l.event_waste_impact_kg) / SUM(l.is_manufactured))::numeric, 4) AS waste_diff,
       ROUND(s.dollars_per_jug_at_end::numeric   - (SUM(l.event_profit_impact)   / SUM(l.is_manufactured))::numeric, 4) AS dollars_diff
FROM sensitivity_breakeven s
JOIN reuse_ledger l ON l.scenario = s.scenario
WHERE s.is_base_case = 1
GROUP BY s.scenario, s.carbon_kg_per_jug_at_end, s.waste_kg_per_jug_at_end, s.dollars_per_jug_at_end
ORDER BY s.scenario DESC;

-- ------------------------------------------------------------------
-- EXPORT TO CSV (same ways as export_for_tableau.sql: pgAdmin Download as CSV, or psql \copy)
--   Table 1 -> tableau_sensitivity_monthly.csv    (about 4,400 rows)
--     SELECT * FROM sensitivity_monthly ORDER BY scenario DESC, weight_multiple, jug_cost, avoided_cost, wash_handling_cost, month_number;
--   Table 2 -> tableau_sensitivity_breakeven.csv  (243 rows)
--     SELECT * FROM sensitivity_breakeven ORDER BY scenario DESC, weight_multiple, jug_cost, avoided_cost, wash_handling_cost;
--
--   psql, typed as one line each:
--     \copy (SELECT * FROM sensitivity_monthly ORDER BY scenario DESC, weight_multiple, jug_cost, avoided_cost, wash_handling_cost, month_number) TO 'tableau_sensitivity_monthly.csv' WITH CSV HEADER
--     \copy (SELECT * FROM sensitivity_breakeven ORDER BY scenario DESC, weight_multiple, jug_cost, avoided_cost, wash_handling_cost) TO 'tableau_sensitivity_breakeven.csv' WITH CSV HEADER

--to create the CSV
--SELECT * FROM sensitivity_monthly
--ORDER BY scenario DESC, weight_multiple, jug_cost, avoided_cost, wash_handling_cost, month_number;

--SELECT * FROM sensitivity_breakeven
--ORDER BY scenario DESC, weight_multiple, jug_cost, avoided_cost, wash_handling_cost;