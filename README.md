# P2P-process-analytics-dashboard

<img width="946" height="431" alt="image" src="https://github.com/user-attachments/assets/4c1c13fa-773a-4828-a4ba-cda030192a6c" />
An interactive R Shiny dashboard simulating a 12-month procure-to-pay pipeline for a mid-to-large enterprise. Built to demonstrate end-to-end finance operations analytics — from invoice ingestion through GL reconciliation — using the same process framework used in SAP-integrated shared services environments.

**Business Problem**
Finance shared services teams at large organisations process thousands of vendor invoices every month. Without visibility into cycle times, payment aging, and reconciliation status, AP teams face:

- **Late payments** that damage supplier relationships and attract penalty charges
- **GL exceptions** that delay month-end close and create audit risk
- **Opaque bottlenecks** that are hard to escalate without data to back them up

This dashboard answers the key questions a Head of Finance or AP Manager asks every Monday morning:

> *"How many invoices did we process last month, and how many were paid on time?"*
> *"Which vendors are sitting in the 60+ day aging bucket?"*
> *"Where are our GL exceptions concentrated, and is the rate improving?"*



**Dataset**
The dataset is synthetically generated using generate_data.R and designed to reflect realistic P2P patterns:

2,000 invoice records across 12 months (January–December 2024)
12 vendors including Kenyan and East African companies
6 departments with distinct processing behaviour
Controlled exception rate (~15% of invoices deliberately aged beyond payment terms to simulate a real AP backlog)
GL reconciliation statuses weighted 78% Reconciled / 14% Pending / 8% Exception — consistent with industry benchmarks for a mid-maturity shared services operation

## Dashboard Features
 
| Section | What it shows |
|---|---|
| **KPI cards** | Total invoices, total value (KES), avg cycle time, on-time payment %, exception rate, pending GL reconciliations |
| **Monthly trend** | Invoice volume vs on-time payment rate on a dual-axis chart across 12 months |
| **Cycle time by dept** | Average processing days broken down by Finance, IT, Operations, HR, Sales, Procurement |
| **Exception rate trend** | Monthly exception % plotted against a 10% control threshold |
| **Vendor aging** | Stacked bar of KES values by aging bucket (Current / 1–30 / 31–60 / 60+ days) per vendor |
| **GL reconciliation** | Donut chart of Reconciled / Pending / Exception status across all invoices |
| **Invoice register** | Searchable, filterable full invoice table with colour-coded payment and GL status |
 
All charts are interactive (hover, zoom, filter) and the sidebar allows slicing by department, vendor, and date range.

**Key Findings from the Simulated Data**

- **Average cycle time: ~15 days** — within acceptable range, but the Operations and HR departments consistently run 3–5 days above the company average, pointing to approval workflow delays
- **On-time payment rate: ~83%** — below the 85% internal target, driven primarily by a cluster of high-value invoices in the 31–60 day aging bucket
- **Exception rate: ~22%** — above the 10% control threshold in Q3, indicating a reconciliation backlog that would warrant an audit review in a live environment
- **Top aging risk vendors:** Kenya Power and Total Energies Kenya carry the highest overdue KES balances, representing working capital risk if left unresolved
- **GL exceptions concentrated in 6100-Consulting** — this GL account shows a disproportionate share of unreconciled entries, likely due to PO mismatches on variable-scope service contracts


**Extending This Project**
Ideas for future iterations:

- Connect to a live PostgreSQL or Google Sheets data source instead of a static CSV
- Add a **predictive late payment model** using logistic regression (R's `glm`) to flag high-risk invoices before they age
- Build a **vendor scorecard** tab ranking suppliers by reliability, volume, and payment compliance
- Integrate with Kenya PPRA open procurement data for a public-sector P2P comparison
