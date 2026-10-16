-- EXPORT FOR TABLEAU
-- This query turns the reuse_ledger view into a small monthly summary table.
-- Run to get the summary table for Tableau visualizations. 

-- The reuse_ledger view has about 3.5 million rows (one per event). Tableau only needs totals per month,
-- scenario, city, route and event type, so we add the events up first for a table with a few hundred rows. 

SELECT city,
       route_id,
       scenario,
       month_date::date                    AS month_date,
       event_type,
       COUNT(*)                            AS events,
       ROUND(SUM(event_carbon_impact)::numeric, 5) AS event_carbon_impact,
       ROUND(SUM(event_logistics_carbon)::numeric, 5) AS event_logistics_carbon,
       ROUND(SUM(event_waste_impact_kg)::numeric, 5) AS event_waste_impact_kg,
       ROUND(SUM(event_profit_impact)::numeric, 5) AS event_profit_impact,
       SUM(is_manufactured)                AS is_manufactured,
       SUM(is_returned)                    AS is_returned,
       SUM(is_lost)                        AS is_lost,
       SUM(is_retired)                     AS is_retired
FROM reuse_ledger
GROUP BY city, route_id, scenario, month_date, event_type
ORDER BY scenario DESC, month_date, city, route_id, event_type;

-- ------------------------------------------------------------------
-- TO SAVE THE RESULT AS A CSV (pick one)
--
-- A. pgAdmin: run the query above in the Query Tool, then click the "Download as CSV" button
--    (down-arrow icon in the results toolbar, or F8). Save as tableau_reuse_ledger.csv.
--
-- B. psql (works the same on every system). Connect, then run this as ONE line, with your own folder.
--    \copy is typed in psql, not in a SQL file window:
--
--    \copy (SELECT city, route_id, scenario, month_date::date AS month_date, event_type, COUNT(*) AS events, ROUND(SUM(event_carbon_impact)::numeric, 5) AS event_carbon_impact, ROUND(SUM(event_logistics_carbon)::numeric, 5) AS event_logistics_carbon, ROUND(SUM(event_waste_impact_kg)::numeric, 5) AS event_waste_impact_kg, ROUND(SUM(event_profit_impact)::numeric, 5) AS event_profit_impact, SUM(is_manufactured) AS is_manufactured, SUM(is_returned) AS is_returned, SUM(is_lost) AS is_lost, SUM(is_retired) AS is_retired FROM reuse_ledger GROUP BY city, route_id, scenario, month_date, event_type ORDER BY scenario DESC, month_date, city, route_id, event_type) TO 'tableau_reuse_ledger.csv' WITH CSV HEADER
--
--    With no folder in front of the file name, the file lands in the folder you were in when you started psql.
--
-- C. VS Code: use your SQL extension's "export results to CSV" option on the result table.
-- ------------------------------------------------------------------
