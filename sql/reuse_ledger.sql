/* ======================================================================
   CHICAGOLAND PROJECT: REUSE VS SINGLE-USE LEDGER

   One row per event. Every impact is a DELTA versus buying a single-use
   jug for the same fill: positive = reuse is better, negative = reuse costs more.

   HOW EACH EVENT IS SCORED
- manufactured : on the day a reusable jug is made we RECORD its whole cost, carbon and
                 eventual plastic waste at once. Its first fill replaces one single-use jug,
                 so we take that single-use jug's cost, carbon and waste off the total.
- returned     : a returned jug is washed and refilled. That refill replaces one more
                 single-use jug (a gain), and we SUBTRACT the wash and the truck trip.
- all other events (purchased, washed, lost, retired): nothing is added. The jug's whole
                 life was already counted on the day it was made.

   ====================================================================== */

CREATE OR REPLACE VIEW reuse_ledger AS
WITH params AS (
    SELECT
        /* --- masses --- */
        0.120 AS single_use_kg,             -- single-use jug. ALPLA catalogue lists a 105 g bottle at 3 L; 120 g used here
        0.360 AS reusable_kg,               -- ASSUMPTION: 3x single-use mass (no source found). Test 2x and 4x.

        /* --- carbon (kg CO2e) --- */
        1.73  AS resin_kgco2e_per_kg,       -- virgin HDPE production, EPA WARM (1.57 per short ton). ACC/Franklin 2020 gives 1.61
        0.044 AS landfill_kgco2e_per_kg,    -- HDPE landfilling, EPA WARM (0.04 per short ton)
        0.030 AS wash_kgco2e,               -- ASSUMPTION: commercial wash per jug, unsourced
        0.40  AS truck_kgco2e_per_mile,     -- ASSUMPTION: electric medium-duty truck, unsourced
        600   AS bottles_per_route_run,     -- ASSUMPTION: jugs collected per route run

        /* --- cost ($) --- */
        0.30  AS single_use_cost_avoided,   -- ASSUMPTION: bottle at brand-owner volume. Filling and distribution are NOT avoided by reuse
        1.10  AS reusable_jug_cost,         -- ASSUMPTION: heavy-duty reusable jug, unsourced
        0.15  AS wash_cost,                 -- ASSUMPTION: unsourced
        0.05  AS handling_cost              -- ASSUMPTION: reverse-logistics handling per return, unsourced
)
SELECT
    COALESCE(s.city, 'Hub Operations')           AS city,
    COALESCE(CAST(s.route_id AS text), 'N/A')    AS route_id,
    e.scenario,
    DATE_TRUNC('month', e.timestamp)             AS month_date,
    e.event_type,

    /* Carbon impact (kg CO2e) */
    CASE e.event_type
        WHEN 'manufactured' THEN
            (p.single_use_kg - p.reusable_kg) * (p.resin_kgco2e_per_kg + p.landfill_kgco2e_per_kg)
        WHEN 'returned_to_store' THEN
            p.single_use_kg * (p.resin_kgco2e_per_kg + p.landfill_kgco2e_per_kg)
            - p.wash_kgco2e
            - p.truck_kgco2e_per_mile * COALESCE(s.route_round_trip_miles, 0) / p.bottles_per_route_run
        ELSE 0
    END AS event_carbon_impact,

    /* Logistics part of the carbon impact on its own (kg CO2e), for charts */
    CASE WHEN e.event_type = 'returned_to_store'
         THEN -p.truck_kgco2e_per_mile * COALESCE(s.route_round_trip_miles, 0) / p.bottles_per_route_run
         ELSE 0 END AS event_logistics_carbon,

    /* Plastic waste impact (kg): single-use jug avoided, reusable jug's own end of life */
    CASE e.event_type
        WHEN 'manufactured'      THEN p.single_use_kg - p.reusable_kg
        WHEN 'returned_to_store' THEN p.single_use_kg
        ELSE 0
    END AS event_waste_impact_kg,

    /* Financial impact ($) */
    CASE e.event_type
        WHEN 'manufactured'      THEN p.single_use_cost_avoided - p.reusable_jug_cost
        WHEN 'returned_to_store' THEN p.single_use_cost_avoided - p.wash_cost - p.handling_cost
        ELSE 0
    END AS event_profit_impact,

    /* Helper columns for Tableau rotation counts */
    CASE WHEN e.event_type = 'manufactured'      THEN 1 ELSE 0 END AS is_manufactured,
    CASE WHEN e.event_type = 'returned_to_store' THEN 1 ELSE 0 END AS is_returned,
    CASE WHEN e.event_type = 'lost_to_leakage'   THEN 1 ELSE 0 END AS is_lost,
    CASE WHEN e.event_type = 'retired'           THEN 1 ELSE 0 END AS is_retired

FROM logistics_events e
CROSS JOIN params p
LEFT JOIN stores s ON e.location_id = s.store_id;
