
SELECT 
    e.scenario,
    COALESCE(s.city, 'Hub Operations') as city,
    COALESCE(s.route_id::text, 'N/A') as route_id,
    DATE_TRUNC('month', e.timestamp) as month_date,
    e.event_type,
    
    -- FINANCIAL IMPACT (Comparison to Single-Use)
    CASE 
        -- We spent $0.80 MORE than we would have on a single-use jug
        WHEN e.event_type = 'manufactured' THEN -0.80 
        -- Every return saves the full cost of a new jug (~$1.30) minus the fee
        WHEN e.event_type = 'returned_to_store' THEN 1.15 
        -- We lose the jug ($1.10) but keep the deposit ($2.00)
        WHEN e.event_type = 'lost_to_leakage' THEN 0.90 
        ELSE 0 
    END as delta_profit_impact,
    
    -- CARBON IMPACT (Comparison to Single-Use)
    CASE 
        -- Reusable emits 0.30kg MORE than single-use at birth
        WHEN e.event_type = 'manufactured' THEN -0.30 -- Reusable (0.45) - Single (0.15)
        -- We save the single-use emission (0.15) minus washing (0.03)
        WHEN e.event_type = 'returned_to_store' THEN 0.12 
        -- We lose the heavy asset (0.45kg) to a landfill
        WHEN e.event_type = 'lost_to_leakage' THEN -0.30 -- Extra plastic wasted compared to single-use
        ELSE 0 
    END as delta_carbon_impact

FROM logistics_events e
LEFT JOIN stores s ON e.location_id = s.store_id;