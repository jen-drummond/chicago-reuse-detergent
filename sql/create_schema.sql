-- 1. Create the Assets Table (The Digital Product Passport)
CREATE TABLE assets (
    asset_id VARCHAR(10) PRIMARY KEY,
    material TEXT,
    weight_grams INT,
    initial_date DATE
);

-- 2. Create the Stores Table
CREATE TABLE stores (
    store_id VARCHAR(10) PRIMARY KEY,
    store_name TEXT,
    miles_from_hub NUMERIC
);

-- 3. Create the Logistics Events Table (The "Life History")
CREATE TABLE logistics_events (
    event_id SERIAL PRIMARY KEY,
    asset_id VARCHAR(10) REFERENCES assets(asset_id),
    location_id TEXT, -- This will be a store_id or 'HUB_AURORA'
    event_type TEXT, -- e.g., 'delivered', 'purchased', 'returned', 'washed'
    timestamp TIMESTAMP
);

SELECT location_id, COUNT(*) 
FROM logistics_events 
GROUP BY location_id;
