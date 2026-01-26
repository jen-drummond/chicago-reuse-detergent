/* ========================================================
   AURORA REUSE JUG PROJECT: ANALYTICS SUITE BY MONTH
   ========================================================
*/

WITH MonthlyStats AS (
    SELECT 
        s.city,
        DATE_TRUNC('month', e.timestamp) as month_date,
        COUNT(CASE WHEN e.event_type = 'purchased' THEN 1 END) as sold,
        COUNT(CASE WHEN e.event_type = 'returned_to_store' THEN 1 END) as returned,
        
        -- Environmental Tipping Point Calculation
        -- Saved (0.12) vs Cost (Transport + Wash)
        SUM(CASE 
            WHEN e.event_type = 'returned_to_store' 
            THEN 0.12 - ((s.miles_from_hub * 0.40 * 0.05) + 0.02)
            ELSE 0 
        END) as monthly_carbon_savings,

        -- Financial Tipping Point Calculation
        -- Reuse Savings ($1.30) minus Lost Jug replacement costs
        SUM(CASE 
            WHEN e.event_type = 'returned_to_store' THEN 1.30 
            WHEN e.event_type = 'lost_to_leakage' THEN -1.10 -- Cost to replace lost assets
            ELSE 0 
        END) as monthly_operating_profit
    FROM logistics_events e
    JOIN stores s ON e.location_id = s.store_id
    GROUP BY s.city, month_date
)
SELECT 
    city,
    month_date,
    sold,
    returned,
    -- Calculate Return Rate % per month
    ROUND((returned::numeric / NULLIF(sold, 0)) * 100, 1) as monthly_return_rate,
    ROUND(monthly_carbon_savings::numeric, 2) as carbon_savings_kg,
    ROUND(monthly_operating_profit::numeric, 2) as profit_usd,
    -- Running Total (Cumulative Profit) for Tableau "J-Curve"
    SUM(monthly_operating_profit) OVER(PARTITION BY city ORDER BY month_date) as cumulative_profit,
    SUM(monthly_carbon_savings) OVER(PARTITION BY city ORDER BY month_date) as cumulative_carbon_savings

FROM MonthlyStats
ORDER BY city, month_date;