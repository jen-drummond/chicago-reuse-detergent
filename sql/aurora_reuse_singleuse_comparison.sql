SELECT 
    COALESCE(s.city, 'Hub Operations') as city,
    COALESCE(s.route_id::text, 'N/A') as route_id,
    e.scenario,
    DATE_TRUNC('month', e.timestamp) as month_date,
    e.event_type,
  
    -- Carbon Impact
    CASE 
        WHEN e.event_type = 'manufactured' THEN -0.30 
        WHEN e.event_type = 'returned_to_store' THEN 0.16
        ELSE 0 
    END as event_carbon_impact,

    -- Financial Impact
    CASE 
        WHEN e.event_type = 'manufactured' THEN -0.80 
        WHEN e.event_type = 'returned_to_store' THEN 1.10
        ELSE 0 
    END as event_profit_impact,

    -- ROTATION HELPER COLUMNS (For Tableau)
    CASE WHEN e.event_type = 'manufactured' THEN 1 ELSE 0 END as is_manufactured,
    CASE WHEN e.event_type = 'returned_to_store' THEN 1 ELSE 0 END as is_returned

FROM logistics_events e
LEFT JOIN stores s ON e.location_id = s.store_id;