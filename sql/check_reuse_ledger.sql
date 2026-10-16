-- LOOK INSIDE THE reuse_ledger VIEW
-- Creating the view (reuse_ledger.sql) only SAVES it and prints "CREATE VIEW". It shows no rows.
-- To see results, highlight ONE query below (from SELECT to the semicolon) and run it.

-- 1. A first look: one sample row for each type of event (90% scenario). Same columns Tableau will see.
--    Notice: manufactured rows have a negative number, returned_to_store a positive one, the rest are 0.
SELECT DISTINCT ON (event_type)
       event_type, city, route_id, month_date::date AS month,
       ROUND(event_carbon_impact::numeric, 3)   AS carbon_kg,
       ROUND(event_waste_impact_kg::numeric, 3) AS waste_kg,
       ROUND(event_profit_impact::numeric, 2)   AS dollars
FROM reuse_ledger
WHERE scenario = '90% Return'
ORDER BY event_type;

-- 2. What does each type of event add to the ledger?
--    One row per event type: how many events, and the smallest / largest value booked per event.
--    manufactured = one fixed (negative) number, returned_to_store = a positive number that varies a little by route,
--    everything else = 0.
SELECT event_type,
       COUNT(*)                                        AS events,
       ROUND(MIN(event_carbon_impact)::numeric, 3)     AS carbon_min_kg,
       ROUND(MAX(event_carbon_impact)::numeric, 3)     AS carbon_max_kg,
       ROUND(MIN(event_waste_impact_kg)::numeric, 3)   AS waste_min_kg,
       ROUND(MAX(event_waste_impact_kg)::numeric, 3)   AS waste_max_kg,
       ROUND(MIN(event_profit_impact)::numeric, 2)     AS dollars_min,
       ROUND(MAX(event_profit_impact)::numeric, 2)     AS dollars_max
FROM reuse_ledger
WHERE scenario = '90% Return'
GROUP BY event_type
ORDER BY event_type;

-- 3. Final totals after 18 months, per jug, for each scenario.
--    Positive = reuse is ahead of single-use. Negative = single-use is still ahead.
SELECT scenario,
       ROUND((SUM(event_carbon_impact)   / SUM(is_manufactured))::numeric, 3) AS carbon_kg_per_jug,
       ROUND((SUM(event_waste_impact_kg) / SUM(is_manufactured))::numeric, 3) AS waste_kg_per_jug,
       ROUND((SUM(event_profit_impact)   / SUM(is_manufactured))::numeric, 3) AS dollars_per_jug
FROM reuse_ledger
GROUP BY scenario
ORDER BY scenario DESC;

-- 4. Month by month running totals for ONE scenario. Look for the month the number crosses from negative to positive:
--    that month is the break-even. Change '90% Return' to '80% Return' or '70% Return' to compare.
SELECT month_date::date AS month,
       ROUND((SUM(SUM(is_returned)) OVER (ORDER BY month_date)
              / SUM(SUM(is_manufactured)) OVER ())::numeric, 2)                         AS returns_per_jug_so_far,
       ROUND((SUM(SUM(event_carbon_impact)) OVER (ORDER BY month_date)
              / SUM(SUM(is_manufactured)) OVER ())::numeric, 3)                         AS carbon_kg_per_jug_so_far,
       ROUND((SUM(SUM(event_waste_impact_kg)) OVER (ORDER BY month_date)
              / SUM(SUM(is_manufactured)) OVER ())::numeric, 3)                         AS waste_kg_per_jug_so_far,
       ROUND((SUM(SUM(event_profit_impact)) OVER (ORDER BY month_date)
              / SUM(SUM(is_manufactured)) OVER ())::numeric, 3)                         AS dollars_per_jug_so_far
FROM reuse_ledger
WHERE scenario = '90% Return'
GROUP BY month_date
ORDER BY month_date;
