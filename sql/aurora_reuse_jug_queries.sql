/* ========================================================
   AURORA REUSE JUG PROJECT: ANALYTICS SUITE
   ========================================================
*/
WITH SystemCalculations AS (
    SELECT 
        s.route_id,
        s.city,
        -- Counts
        COUNT(CASE WHEN e.event_type = 'purchased' THEN 1 END) as sold,
        COUNT(CASE WHEN e.event_type = 'returned_to_store' THEN 1 END) as returned,
        COUNT(CASE WHEN e.event_type = 'lost_to_leakage' THEN 1 END) as lost,

        -- CARBON CALCULATION
        -- (0.12kg saved per return) - (Transport Cost) - (Washing Cost)
        (COUNT(CASE WHEN e.event_type = 'returned_to_store' THEN 1 END) * 0.12) - 
        SUM(CASE WHEN e.event_type = 'returned_to_store' THEN (s.miles_from_hub * 1 * 0.40 * 0.05) + 0.02 ELSE 0 END) as net_carbon,

        -- ECONOMICS
        (COUNT(CASE WHEN e.event_type = 'returned_to_store' THEN 1 END) * (1.50 - 0.20)) as reuse_savings,
        (COUNT(CASE WHEN e.event_type = 'lost_to_leakage' THEN 1 END) * (2.00 - 1.10)) as forfeited_deposit_profit
    FROM logistics_events e
    JOIN stores s ON e.location_id = s.store_id
    GROUP BY s.route_id, s.city
)
SELECT 
    route_id,
    city,
    sold,
    returned,
    ROUND(net_carbon::numeric, 2) as carbon_impact_kg,
    ROUND((reuse_savings + forfeited_deposit_profit)::numeric, 2) as total_profit,
    
    -- SYSTEM TOTALS
    ROUND(SUM(net_carbon) OVER()::numeric, 2) as system_wide_carbon_kg,
    ROUND(SUM(reuse_savings + forfeited_deposit_profit) OVER()::numeric, 2) as system_wide_profit
FROM SystemCalculations
ORDER BY route_id, net_carbon DESC;