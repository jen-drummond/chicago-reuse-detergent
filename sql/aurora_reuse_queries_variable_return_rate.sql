/* ========================================================
   AURORA REUSE JUG PROJECT: ANALYTICS SUITE BY MONTH
   AND VARIABLE RETURN RATES
   ========================================================
*/

SELECT 
    COALESCE(s.city, 'Hub Operations') as city,
    COALESCE(s.route_id::text, 'N/A') as route_id,
    e.scenario,
    DATE_TRUNC('month', e.timestamp) as month_date,
    e.event_type,
  
    -- Individual Carbon Impact per Event (kg)
    CASE 
        WHEN e.event_type = 'manufactured' THEN (0.15-0.45) -- Carbon Debt for Re-use jug, Single Use is 0.15 kg CO2
        WHEN e.event_type = 'returned_to_store' THEN 0.12 - ((s.miles_from_hub * 0.05 * 0.01) + 0.02)
        WHEN e.event_type = 'lost_to_leakage' THEN -0.60 
        ELSE 0 
    END as event_carbon_impact,
    -- Individual Financial Impact per Event ($)
    CASE 
        WHEN e.event_type = 'manufactured' THEN (- 1.10) -- Net Capex (Now Reuse, but could update to Single-use cost (0.3) minus Reusable cost)
        WHEN e.event_type = 'returned_to_store' THEN (1.30 - 0.15) -- Reuse Savings minus logistics (0.10) & washing (0.05)
        WHEN e.event_type = 'lost_to_leakage' THEN -1.10
        ELSE 0 
    END as event_profit_impact
FROM logistics_events e
LEFT JOIN stores s ON e.location_id = s.store_id;