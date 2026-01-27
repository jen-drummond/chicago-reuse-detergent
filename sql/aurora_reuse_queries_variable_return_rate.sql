/* ========================================================
   AURORA REUSE JUG PROJECT: ANALYTICS SUITE BY MONTH
   AND VARIABLE RETURN RATES
   ========================================================
*/

WITH InitialDebt AS (
    -- Every reusable jug starts with a "Carbon Debt" of 0.5kg CO2 (manufacture cost)
    -- and a $1.10 financial cost.
    SELECT 
        city,
        scenario,
        COUNT(DISTINCT asset_id) * 1.10 as total_capex,
        COUNT(DISTINCT asset_id) * 0.50 as initial_carbon_debt 
    FROM logistics_events e
    JOIN stores s ON e.location_id = s.store_id
    GROUP BY city, scenario
),
MonthlyStats AS (
    SELECT 
        s.city,
        e.scenario,
        DATE_TRUNC('month', e.timestamp) as month_date,
        COUNT(CASE WHEN e.event_type = 'purchased' THEN 1 END) as sold,
        COUNT(CASE WHEN e.event_type = 'returned_to_store' THEN 1 END) as returned,
        
        -- CARBON: Savings (0.12) - EV Energy (0.01) - Washing (0.02)
        -- Note: We use 0.01 now because EV is very efficient
        SUM(CASE 
            WHEN e.event_type = 'returned_to_store' THEN 0.12 - ((s.miles_from_hub * 0.05 * 0.01) + 0.02)
            WHEN e.event_type = 'lost_to_leakage' THEN -1.5 -- Penalty for needing a new plastic replacement
            ELSE 0 
        END) as monthly_carbon_savings,

        -- ECONOMICS: 
        -- Revenue: $1.30 per return
        -- Cost: $2.00 "Reverse Logistics Fee" per return (Shared Truck model)
        SUM(CASE 
            WHEN e.event_type = 'returned_to_store' THEN (1.30 - 0.15) -- $0.15 is the "Shared Truck" fee per jug
            WHEN e.event_type = 'lost_to_leakage' THEN -1.10 -- Cost to replace the asset
            ELSE 0 
        END) as monthly_net_op_profit
    FROM logistics_events e
    JOIN stores s ON e.location_id = s.store_id
    GROUP BY s.city, e.scenario, month_date
)
SELECT 
    m.city,
    m.scenario,
    m.month_date,
    -- Financial J-Curve: Start at -Capex, add operating profit
    SUM(m.monthly_net_op_profit) OVER(PARTITION BY m.city, m.scenario ORDER BY m.month_date) 
        - i.total_capex as cumulative_profit_usd,
        
    -- Carbon J-Curve: Start at +Debt (Bad), subtract savings (Good)
    i.initial_carbon_debt - 
    SUM(m.monthly_carbon_savings) OVER(PARTITION BY m.city, m.scenario ORDER BY m.month_date) 
        as current_carbon_footprint_kg
FROM MonthlyStats m
JOIN InitialDebt i ON m.city = i.city AND m.scenario = i.scenario
ORDER BY m.scenario, m.city, m.month_date;