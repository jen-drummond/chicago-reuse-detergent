# Chicago Circular: Reuse Logistics & Sustainability Modeling
## Overview
This repository contains a technical simulation and data model for a closed-loop reusable laundry detergent system in the Chicagoland area. Leveraging the TerraCycle Aurora Operations Center as a central hub, the project models the logistics, carbon footprint, and economic viability of replacing 1 million single-use HDPE jugs with a durable, circular alternative.

This project demonstrates the cost and environmental benefits of switching from single use to reuse for a specific product (laundry detergent) in Chicagoland. 

## Tech Stack
Data Engineering: Python (Pandas, NumPy, SQLAlchemy)
Database: PostgreSQL (Digital Product Passport architecture)
Geospatial: OSmnx / Google Maps API (Retail anchor modeling)
Visualization: Tableau (Sustainability KPI Dashboards)

## Project Structure
├── data/               # Synthetic datasets for 50 stores & 100k assets
├── sql/                # Schema definitions & comparative impact queries
├── notebooks/          # Logic for variable return rates (70%, 80%, 90%)
├── visuals/            # Tableau dashboards (Carbon vs. Cost Tipping Points)
└── README.md

## Methodology & Assumptions
Carbon Modeling: Integrated Illinois grid mix (ComEd) data (54% Nuclear, 15% Renewables) to calculate sanitation emissions.

Logistics: Modeled a "Spiderweb" route structure using Class 8 Electric Vehicles (0.40 kg CO2/mile).

Return Rates: Tested system resilience against variable consumer behavior (70–90% return rates).

## Setup & Installation
To replicate the virtual environment and install dependencies:

Bash
python3 -m venv .venv
source .venv/bin/activate
pip3 install pandas numpy sqlalchemy psycopg2-binary osmnx
pip3 freeze > requirements.txt