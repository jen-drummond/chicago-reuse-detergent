-- CHECK THAT THE DATABASE HOLDS THE LATEST SIMULATION
-- Run in pgAdmin or the VS Code SQL extension, connected to aurora_reuse_jug_db.

-- 1. Row counts. Expect: stores 50, assets 100000 (or your NUM_JUGS), logistics_events about 3.5 million.
SELECT 'stores' AS table_name, COUNT(*) AS row_count FROM stores
UNION ALL SELECT 'assets', COUNT(*) FROM assets
UNION ALL SELECT 'logistics_events', COUNT(*) FROM logistics_events;

-- 2. Date range. Expect first = 2026-01-01 and last <= 2027-06-30.
--    A last date in 2028 means the OLD data (no 18-month cut-off) is still loaded.
SELECT MIN(timestamp) AS first_event, MAX(timestamp) AS last_event FROM logistics_events;

-- 3. Event types. Expect five: lost_to_leakage, manufactured, purchased, returned_to_store, washed.
--    'retired' appears only if jugs reach their 10-use design life inside the study window (they do not in 18 months).
SELECT event_type, COUNT(*) FROM logistics_events GROUP BY event_type ORDER BY event_type;

-- 4. Returns per jug at month 18 by scenario. Expect about 4.05 (90%), 2.87 (80%), 2.02 (70%) with the settings in the notebook.
SELECT e.scenario,
       COUNT(*) FILTER (WHERE event_type = 'returned_to_store')::numeric
       / COUNT(*) FILTER (WHERE event_type = 'manufactured') AS returns_per_jug
FROM logistics_events e
GROUP BY e.scenario ORDER BY e.scenario DESC;

-- 4b. Jug id format. Expect JUG_000000 style (6 digits). Old data used 5 digits (JUG_00000).
SELECT MIN(asset_id) AS first_id, MAX(asset_id) AS last_id FROM assets;

-- 5. Stores. Expect 50 stores, route_round_trip_miles filled in, and counts by city that match population (Aurora 15, Naperville 12, ...).
SELECT city, COUNT(*) AS stores, ROUND(AVG(route_round_trip_miles)::numeric, 1) AS avg_route_miles
FROM stores GROUP BY city ORDER BY stores DESC;

-- 6. Column check. Expect city, lat, lon, route_id, miles_from_hub, route_round_trip_miles to be listed for stores,
--    and scenario for logistics_events.
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name IN ('stores', 'logistics_events') ORDER BY table_name, ordinal_position;

-- 7. After you create the view (reuse_ledger.sql): cumulative results at month 18 per scenario.
--    Needs the view to exist.
SELECT scenario,
       ROUND(SUM(event_carbon_impact)::numeric / 100000, 3)   AS carbon_kg_per_jug,
       ROUND(SUM(event_waste_impact_kg)::numeric / 100000, 3) AS waste_kg_per_jug,
       ROUND(SUM(event_profit_impact)::numeric / 100000, 3)   AS dollars_per_jug
FROM reuse_ledger GROUP BY scenario ORDER BY scenario DESC;
