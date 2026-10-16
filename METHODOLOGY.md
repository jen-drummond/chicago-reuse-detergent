# Methodology: assumptions, equations, sources, limitations

This is the technical companion to the [README](../README.md). It records what the model assumes, where each number comes from, and how much each one matters. It replaces the earlier `README_technical_assumptions.md`.

**Status labels used below**
- **Sourced**: taken from a cited document or listing.
- **Sourced range**: a cited listing supports a range, and the model tests that range.
- **Assumption**: no source. Chosen by me, disclosed, and tested in the sensitivity analysis where it matters.

---

## 1. What this is and is not

- A **model**, not a measurement. No company data was used.
- The dataset is **synthetic**. No public dataset exists for a reusable detergent loop in Chicago, so I generated one.
- **100,000 jugs** are simulated per scenario. The 1 million jugs per year figure is a design target.
- The stores, routes and hub are **hypothetical**. The Aurora hub is a real, documented operations center ([source](https://www.packworld.com/sustainable-packaging/recycling/article/22953911/terracycle-launches-aurora-ill-operations-center)) used as a stand-in. No relationship with TerraCycle or any retailer exists.

## 2. Data model

Three tables in PostgreSQL: `stores`, `assets` (one row per jug) and `logistics_events` (one row per thing that happens to a jug).

| Event | Meaning |
|---|---|
| `manufactured` | Jug made and put into the fleet (all jugs, on the launch date) |
| `purchased` | A shopper buys a filled jug at a store |
| `returned_to_store` | The empty jug is brought back to the store it came from |
| `washed` | Cleaned at the hub and ready to refill |
| `lost_to_leakage` | The shopper does not return it. Gone for good: lost jugs are never replaced |
| `retired` | Reached the 10-use design life (does not occur within 18 months) |

Jug ids are `JUG_000000` to `JUG_099999`. Three scenarios (90%, 80%, 70% of used jugs returned each cycle) each launch 100,000 jugs, so the events table holds about 3.5 million rows.

## 3. Store network and routes

- **50 stores** in six areas: Aurora, Naperville, Evanston, Schaumburg, Oak Park and Lincoln Park. Store counts are allocated in proportion to population (largest-remainder method): Aurora 15, Naperville 12, Evanston 7, Schaumburg 6, Lincoln Park 6, Oak Park 4.
- **Locations are synthetic.** Each store is placed at random within about 2 miles of its area's centre. No real addresses and no chain names are used.
- Populations: 2020 Census figures compiled at [biggestuscities.com](https://www.biggestuscities.com/il/2020). Lincoln Park is a Chicago neighbourhood, not a municipality, so its 70,000 is an approximation. *Status: sourced, except Lincoln Park (assumption).*
- **Routes:** K-means groups the 50 stores into 5 routes (seed 42). Each route's round trip is hub, nearest unvisited store, and so on, back to the hub, in straight-line miles multiplied by a **road factor of 1.3**. *Status: the 1.3 is an assumption; urban values are commonly quoted around 1.2 to 1.4.*
- Each store carries its route's round-trip miles, which the carbon ledger uses.

### A mistake in an earlier version
The first version placed stores at random distances from the hub and sent one truck to each store. Truck emissions came out unrealistically large. The fix was multi-stop routes, with each jug charged only its share of its route's trip (section 6).

## 4. Jug lifecycle (simulation)

Each jug has its own clock. Durations are uniform random draws, in days:

| Phase | Range | Status |
|---|---|---|
| Launch stagger (jug reaches the shelf) | 0 to 29 | Assumption |
| Shelf time (hub to purchase) | 2 to 13 | Assumption |
| Use (about 60 loads) | 45 to 90 | Assumption; 60 loads over about 300 loads per household per year ([ENERGY STAR via home-water-works.org](https://home-water-works.org/indoor-use/clothes-washer)) |
| Return lag | 3 to 14 | Assumption |
| Wash | 3 fixed | Assumption |

One loop averages roughly 87 days. **Design life is 10 uses** (assumption, untested against real data). Events after 30 June 2027 are dropped, giving an 18-month window from 1 January 2026.

At 18 months the model averages **4.05, 2.87 and 2.02 returns per jug** at 90%, 80% and 70% return. The fleet is bought up front, which is why the cost ledger starts in debt.

## 5. Market sizing (context only; does not drive results)

| Step | Value | Source |
|---|---|---|
| Chicagoland households | about 3.3 million | US Census / [CMAP](https://cmap-cmapgis.opendata.arcgis.com/search?collection=dataset) (verify the exact figure) |
| Loads per household per year | about 300 | ENERGY STAR, via the link above |
| Loads per large jug | about 60 | Typical label claim |
| Jugs per household per year | 5 | Calculated |
| Total market | about 16.5 million jugs per year | Calculated |
| Modeled program | 1 million jugs per year, about 6% of jug sales | Chosen scenario |

The 6% is a share of **laundry-jug sales**, not of regional plastic waste.

## 6. The ledger: how every event is scored

Every number is a **difference versus single-use**: reusable minus single-use. Positive means reuse is ahead.

- **Booked** means written into the ledger. Making a jug books its whole carbon, waste and cost on day one.
- **Charged** means subtracted from a gain. A return's wash and truck trip are subtracted from the benefit that return earns.

Think of it as a loan: making the jug is the debt, and each return is a repayment.

### Inputs (all in one block in `sql/reuse_ledger.sql`)

| Input | Base value | Status |
|---|---|---|
| Single-use jug mass | 0.120 kg | Sourced range: a 3 L detergent bottle is listed at 105 g ([ALPLA](https://product-catalogue.alpla.com/product/3000-ml-detergent-bottle-105-g)) |
| Reusable jug mass | 0.360 kg (3x) | **Assumption, and the most influential input.** Tested at 2x, 3x and 4x |
| Virgin HDPE production | 1.73 kg CO2e per kg | Sourced: [EPA WARM, Plastics](https://archive.epa.gov/epawaste/conserve/tools/warm/pdfs/Plastics.pdf). A cradle-to-gate study from the [American Chemistry Council](https://americanchemistry.com/content/download/8059/file/Cradle-to-Gate-Life-Cycle-Analysis-of-High-Density-Polyethylene-HDPE-Resin.pdf) gives 1.61 |
| HDPE landfill disposal | 0.044 kg CO2e per kg | Sourced: EPA WARM, as above |
| Wash | 0.03 kg CO2e per jug | Assumption |
| Truck | 0.40 kg CO2e per mile | Assumption (electric medium-duty truck) |
| Jugs collected per route run | 600 | Assumption |
| Single-use cost avoided per refill | $0.30 | Sourced range: factory prices of about $0.18 to $0.29 for 2 to 3 L HDPE bottles at 1,000 to 10,000 pieces (Global Sources listing, see Source list below); a 115 g bottle listed at $0.79 in small quantities (see Source list below). Tested at $0.30, $0.45 and $0.60 |
| Reusable jug cost | $1.10 | Sourced range, conservative end. A resin-only cost for 360 g is about $0.50; adding cap, conversion and margin with the component ranges from a supplier-style cost build-up gives roughly $0.80 to $1.05 at 100,000 units. Small-lot distributor prices are far higher ($2.71 to $3.56 for a 1-gallon jug, Berlin Packaging item 3003B55NAT, https://www.berlinpackaging.com/3003b55nat-1-gal-natural-hdpe-plastic-bulk-packed-industrial-round-grab-n-go-jugs-white-screw-top-cap/?utm_source=google&utm_medium=organic&utm_campaign=surfaces-across-google&utm_term=3003B55NAT&srsltid=AU7gw4UeXTa32AILRon4w9jgBwEXq7GFGtuo_Bk5YJETJWmokch75aoITgc). Tested at $0.70, $0.90 and $1.10 |
| Wash cost | $0.15 per return | Assumption |
| Handling cost | $0.05 per return | Assumption |

The cost build-up behind the reusable-jug range came from an AI-generated estimate, not a published source, so I treat it as a plausibility check on the listings above and do not cite it as evidence.

### Equations (per jug, versus one single-use jug)

Let `S` = single-use mass, `R` = reusable mass, `f` = resin plus landfill factor = 1.73 + 0.044 = 1.774 kg CO2e per kg.

| Event | Carbon (kg CO2e) | Waste (kg) | Dollars |
|---|---|---|---|
| `manufactured` | (S - R) x f = **-0.426** | S - R = **-0.240** | avoided - jug cost = 0.30 - 1.10 = **-0.80** |
| `returned_to_store` | S x f - wash - truck x route miles / 600 = **+0.114 to +0.169** | S = **+0.120** | avoided - wash - handling = **+0.10** |
| All other events | 0 | 0 | 0 |

**Why manufacture is a debt.** The reusable jug carries 0.24 kg more plastic than the single-use jug it replaces. Its first fill replaces a single-use jug, which is already netted in the manufactured row. Disposal of the reusable jug at end of life is booked on day one, which is slightly conservative.

**Break-even in returns per jug** is the up-front debt divided by the net credit per return:

| Currency | Debt | Credit per return | Returns needed per jug |
|---|---|---|---|
| Waste | 0.240 kg | 0.120 kg | **2** (equal to the mass ratio minus 1) |
| Carbon | 0.426 kg | about 0.145 kg (average over routes) | **about 2.9** |
| Cost (base) | $0.80 | $0.10 | **8** |

Waste and carbon are reachable within the study window at high return rates. Cost needs 8 returns, but a 90% return rate with a 10-use cap averages only about 5.85 lifetime returns, so **running the system longer cannot fix cost on its own**. Faster product turnover would only compress the timeline, not move these thresholds.

### The roll-up
Tableau and the exports show **running cumulative totals per jug manufactured**: the running sum of each currency divided by the running count of jugs. The month a running total first reaches zero is the break-even month.

## 7. Scenarios and results (base case)

| | 90% | 80% | 70% |
|---|---|---|---|
| Returns per jug at month 18 | 4.05 | 2.87 | 2.02 |
| Waste break-even | month 9 | month 11 | month 18 |
| Carbon break-even | month 13 | not reached | not reached |
| Cost break-even | not reached | not reached | not reached |
| Waste at month 18, kg per jug | +0.246 | +0.105 | +0.003 |
| Carbon at month 18, kg CO2e per jug | +0.161 | -0.009 | -0.132 |
| Dollars at month 18, per jug | -0.395 | -0.513 | -0.598 |
| Whole 100,000-jug fleet: waste (tonnes) | +24.6 | +10.5 | +0.3 |
| Whole fleet: carbon (tonnes CO2e) | +16.1 | -0.9 | -13.2 |
| Whole fleet: dollars | -$39,500 | -$51,300 | -$59,800 |

## 8. Sensitivity analysis

`sql/sensitivity_for_tableau.sql` re-scores the same simulated events under 81 assumption sets (3 x 3 x 3 x 3) without re-simulating. It varies:

| Lever | Values tested |
|---|---|
| Reusable jug weight (multiple of the 120 g single-use jug) | 2x (240 g), 3x (360 g, base), 4x (480 g) |
| Reusable jug cost | $0.70, $0.90, $1.10 (base) |
| Single-use cost avoided per refill | $0.30 (base), $0.45, $0.60 |
| Wash plus handling cost per return | $0.10, $0.20 (base), $0.30 |

Return rate is the fifth dimension (the three scenarios). The base case in the sensitivity file ties out exactly to the main ledger (check 1 in the file returns all zeros).

**Findings**
- **Weight decides carbon and waste.** At 2x, carbon breaks even at months 7, 8 and 10 (90, 80, 70%). At 3x, only 90% reaches carbon break-even (month 13). At 4x, none do. Waste break-even at 90 / 80 / 70% is months 6 / 6 / 7 at 2x, 9 / 11 / 18 at 3x, and 13 / not within 18 months / not within 18 months at 4x.
- **Cost is decided by the cost inputs.** At the base jug cost and wash plus handling, 90% return is cost-neutral by month 18 when the avoided single-use cost is at least about $0.38. At $0.45 it breaks even in month 12, and at $0.60 in month 6.
- **Counts:** cost breaks even within 18 months in 63, 51 and 48 of the 81 sets at 90, 80 and 70% return. Only 12, 3 and 3 of the 27 sets with a $0.30 single-use cost do.

**Caveats**
- The four levers vary independently. Some combinations are not internally consistent, for example a 480 g jug priced at $0.70 (a heavier jug would use more resin and plausibly cost more). Read the break-even map as a map of conditions, not as 81 forecasts.
- The cost-avoided lever covers only the single-use container. Filling and distribution costs are assumed unchanged between the two systems.

## 9. Limitations

- Synthetic data. Results show how the system behaves under stated assumptions, not what a real rollout would produce.
- **Closed batch.** Lost jugs are not replaced, and no new jugs are added. A steady-state program would replenish the fleet.
- **Return behaviour** is the biggest uncertainty and is only bounded by three scenarios. Return rate does not change with deposits, incentives or store convenience.
- Wash-line energy, water use and labor are estimates, not facility data. Water use is not modeled.
- Truck capacity, driver hours and fleet size are not modeled. Each jug is charged a fixed share of its route's round trip.
- Store selection is illustrative, not based on store-level sales data.
- One product category (laundry detergent), one jug design, one design life (10 uses, untested).
- **Producer-responsibility fees (EPR) and deposits are not modeled.** Oregon's program began charging fees in July 2025. I have not verified Illinois's status or any HDPE fee rate. Fees on single-use packaging would raise the avoided cost, which is one reason that lever matters.
- Disposal is landfill only, for both jug types. Recycling is not credited to either.
- Cost inputs without a cited source (wash, handling) are placeholders pending real supplier and retailer quotes.

## 10. Sources

- EPA WARM, Plastics (virgin HDPE production and landfill factors): https://archive.epa.gov/epawaste/conserve/tools/warm/pdfs/Plastics.pdf
- American Chemistry Council, cradle-to-gate HDPE resin (comparison value 1.61): https://americanchemistry.com/content/download/8059/file/Cradle-to-Gate-Life-Cycle-Analysis-of-High-Density-Polyethylene-HDPE-Resin.pdf
- ALPLA, 3000 ml detergent bottle, 105 g (single-use mass): https://product-catalogue.alpla.com/product/3000-ml-detergent-bottle-105-g
- Global Sources HDPE bottle listings (single-use cost range): https://www.kgint.com/collections/hdpe-bulk-bottles?srsltid=AU7gw4ViBFDv1bBDs8g8UtBK31nnD5ZZROXWYu6OW6HsftAxVyMbWLzi OR https://www.globalsources.com/manufacturers/laundry-detergent-bottle.html 
- Berlin Packaging item 3003B55NAT (small-lot reusable jug price):(https://www.berlinpackaging.com/3003b55nat-1-gal-natural-hdpe-plastic-bulk-packed-industrial-round-grab-n-go-jugs-white-screw-top-cap/?utm_source=google&utm_medium=organic&utm_campaign=surfaces-across-google&utm_term=3003B55NAT&srsltid=AU7gw4UeXTa32AILRon4w9jgBwEXq7GFGtuo_Bk5YJETJWmokch75aoITgc)
- TerraCycle Aurora operations center: https://www.packworld.com/sustainable-packaging/recycling/article/22953911/terracycle-launches-aurora-ill-operations-center
- 2020 Census populations, Illinois: https://www.biggestuscities.com/il/2020
- CMAP demographic data: https://cmap-cmapgis.opendata.arcgis.com/search?collection=dataset
- Loads of laundry per household (ENERGY STAR): https://home-water-works.org/indoor-use/clothes-washer
- Oregon EPR background: https://www.packagingdigest.com/sustainability/inside-oregon-s-new-epr-program
