# Chicago Circular: Reuse Logistics & Sustainability Modeling

**Contact**
Jen Drummond, PhD Circular Systems & Sustainability Consultant
Website: becomingcircular.com

## Overview
This repository contains a technical simulation and data model for a **closed-loop reusable laundry detergent system** in the Chicagoland area. Leveraging the TerraCycle Aurora Operations Center as a central hub, the project models the logistics, carbon footprint, and economic viability of replacing 1 million single-use HDPE jugs with a durable, circular alternative.

> **[View the Full Presentation & Slide Deck Here](https://becomingcircular.com/chicago-project)**

## Key Results (Draft)
* **Carbon Neutrality:** The reuse loop outperforms single-use packaging after **4.2 rotations**.
* **Economic Tipping Point:** Achieved at a **85% return rate**, resulting in a $1.15 net saving per jug.
* **Market Impact:** 1 million jugs eliminated represents a **6% reduction** in regional plastic waste.

![Carbon Tipping Point Plot](visuals/carbon_tipping_point.png)

## Tech Stack
* **Data Engineering:** Python (Pandas, NumPy, SQLAlchemy)
* **Database:** PostgreSQL (Digital Product Passport architecture)
* **Geospatial:** OSmnx / Google Maps API (Retail anchor modeling)
* **Visualization:** Tableau (Sustainability KPI Dashboards)

## Project Structure
* `data/`: Synthetic datasets for 50 stores & 100k assets
* `sql/`: Schema definitions & comparative impact queries
* `notebooks/`: Logic for variable return rates (70%, 80%, 90%)
* `visuals/`: Tableau dashboards (Carbon vs. Cost Tipping Points)

## Methodology & Assumptions
* **Carbon Modeling:** Integrated Illinois grid mix (ComEd) data (54% Nuclear, 15% Renewables).
* **Logistics:** Modeled a "Spiderweb" route structure using Class 8 Electric Vehicles (0.40 kg CO2/mile).
* **Return Rates:** Tested system resilience against variable consumer behavior.

## Setup & Installation

To ensure reproducibility, this project uses a **Python Virtual Environment (.venv)**. 
1. Initialize Environment & Dependencies:
   python3 -m venv .venv
   source .venv/bin/activate  # Windows: .venv\Scripts\activate
   pip3 install -r requirements.txt

2. Database Configuration:
   - Create a PostgreSQL database named 'aurora_reuse_jug_db'.
   - Run 'sql/create_schema.sql' to initialize the relational tables.

3. Execution Order:
   - Run 'notebooks/create_chicago_reuse_data.ipynb' to generate synthetic logistics events.
   - Run 'python/upload_to_postgres.py' to populate the database.
   - Use the 'sql/' folder scripts for comparative queries or connect to Tableau.