/* ========================================================
   AURORA REUSE JUG PROJECT: ANALYTICS SUITE
   ========================================================
*/


WITH SystemCalculations AS (
    SELECT 
        s.store_name,
        -- Counts
        COUNT(CASE WHEN e.event_type = 'purchased' THEN 1 END) as sold,
        COUNT(CASE WHEN e.event_type = 'returned_to_store' THEN 1 END) as returned,
        COUNT(CASE WHEN e.event_type = 'lost_to_leakage' THEN 1 END) as lost,

        -- CARBON: (0.12kg saved) - (Return Trip 1x * EV Factor 0.04 CO2/kg * Load Share at 5% now) - Washing
        (COUNT(CASE WHEN e.event_type = 'returned_to_store' THEN 1 END) * 0.12) - 
        SUM(CASE WHEN e.event_type = 'returned_to_store' THEN (s.miles_from_hub * 1 * 0.40 * 0.05) + 0.02 ELSE 0 END) as net_carbon,

        -- ECONOMICS (The DRS Model)
        -- Profit from avoided new jugs ($1.30 per return)
        (COUNT(CASE WHEN e.event_type = 'returned_to_store' THEN 1 END) * (1.50 - 0.20)) as reuse_savings,
        -- Profit from kept deposits on lost jugs ($2.00 deposit - $1.10 replacement cost)
        (COUNT(CASE WHEN e.event_type = 'lost_to_leakage' THEN 1 END) * (2.00 - 1.10)) as forfeited_deposit_profit
    FROM logistics_events e
    JOIN stores s ON e.location_id = s.store_id
    GROUP BY s.store_name
)
SELECT 
    store_name,
    ROUND(net_carbon::numeric, 2) as carbon_impact_kg,
    ROUND((reuse_savings + forfeited_deposit_profit)::numeric, 2) as total_financial_impact,
    
    -- SYSTEM TOTALS (Window Functions)
    SUM(net_carbon) OVER() as global_carbon_savings,
    SUM(reuse_savings + forfeited_deposit_profit) OVER() as global_cash_flow
FROM SystemCalculations
ORDER BY net_carbon DESC;