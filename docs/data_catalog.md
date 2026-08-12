# Gold Layer Data Catalog

This document describes the business-facing views in the `gold` schema. The gold layer is built on top of the cleaned silver layer and is designed for analytics, reporting, and star-schema consumption.

## 1. Overview of the Gold Layer

The gold layer contains three main business objects:

- `gold.dim_customers` — customer dimension
- `gold.dim_products` — product dimension
- `gold.fact_sales` — sales fact table

These views are intended to provide a simple, business-friendly structure for BI reporting and dashboarding.

---

## 2. gold.dim_customers

### Purpose
This view stores one row per customer and is used to analyze customer behavior and  demographics

It combines customer information from the CRM source with supporting ERP contact and geographic details, while keeping the CRM record as the master source of truth.

### Columns

| Column | Purpose | Example values |
|---|---|---|
| `customer_key` | Surrogate key used for joining to the fact table; unique value for each customer | 1, 2, 3 |
| `customer_id` | Source customer ID from CRM | 11000, 11001 |
| `customer_number` | Business key from source system | AW00011000 |
| `first_name` | Customer first name | Jon, Eugene |
| `last_name` | Customer last name | Yang, Huang |
| `country` | Customer country from ERP location data | Australia, Germany |
| `gender` | Standardized customer gender | Male, Female, n/a |
| `marital_status` | Standardized marital status | Single, Married, n/a |
| `birth_date` | Customer birth date from ERP dataset | 1971-10-06 |
| `create_date` | Customer account creation date from CRM | 2025-10-06 |

### Example rows

```sql
SELECT TOP 5 *
FROM gold.dim_customers;
```

Example output:

| customer_key | customer_id | customer_number | first_name | last_name | country | gender | marital_status | birth_date | create_date |
|---|---:|---|---|---|---|---|---|---|---|
| 1 | 11000 | AW00011000 | Jon | Yang | Australia | Male | Married | 1971-10-06 | 2025-10-06 |
| 2 | 11001 | AW00011001 | Eugene | Huang | Australia | Male | Single | 1976-05-10 | 2025-10-06 |
| 3 | 11002 | AW00011002 | Ruben | Torres | Australia | Male | Married | 1971-02-09 | 2025-10-06 |

### Business logic used
- CRM customer data is treated as the master source for customer identity and personal information.
- ERP customer data fills missing or standardized values such as gender and birth date.
- ERP location data provides the `country` dimension.
- Values like `M`, `F`, `S`, and `n/a` are normalized to more readable labels.

---

## 3. gold.dim_products

### Purpose
This view stores one row per active product and is used to analyze product performance and category coverage

It combines the product information from the CRM product table with ERP product category details and keeps only product records that are still active (`prd_end_dt IS NULL`).

### Columns

| Column | Purpose | Example values |
|---|---|---|
| `product_key` | Surrogate key used for joining to the fact table | 1, 2, 3 |
| `product_id` | Source product ID from CRM | 210, 211 |
| `category_id` | Product category ID derived from product key | CO_RF, AC_HE |
| `product_number` | Product key from source data | CO-RF-FR-R92B-58 |
| `product_name` | Product name from the CRM source | HL Road Frame - Black- 58 |
| `category` | Main category label | Accessories, Bikes |
| `subcategory` | More granular product category | Bike Racks, Bottle Cages |
| `maintenance` | Product maintenance flag | Yes, No |
| `cost` | Product cost used for value analysis | 12, 14, 0 |
| `line` | Product line normalized to business meaning | Road, Mountain, Other Sales |
| `start_date` | Product start date | 2003-07-01 |

### Example rows

```sql
SELECT TOP 5 *
FROM gold.dim_products;
```

Example output:

| product_key | product_id | category_id | product_number | product_name | category | subcategory | maintenance | cost | line | start_date |
|---|---:|---|---|---|---|---|---|---:|---|---|
| 1 | 210 | CO_RF | CO-RF-FR-R92B-58 | HL Road Frame - Black- 58 | Road | Frame | No | 0 | Road | 2003-07-01 |
| 2 | 211 | CO_RF | CO-RF-FR-R92R-58 | HL Road Frame - Red- 58 | Road | Frame | No | 0 | Road | 2003-07-01 |
| 3 | 212 | AC_HE | AC-HE-HL-U509-R | Sport-100 Helmet- Red | Accessories | Helmets | Yes | 12 | Other Sales | 2011-07-01 |

### Business logic used
- Product history is removed by selecting only products with no end date.
- `cat_id` is created from the product key prefix, allowing matching with ERP category data.
- Product line and category fields are normalized into readable business labels.
- Null product costs are replaced with `0` during the silver layer before they reach the gold layer.

---

## 4. gold.fact_sales

### Purpose
This view is the transactional fact table for sales. It stores order-level sales records and links each transaction to its corresponding customer and product through surrogate keys.

This is the main analytical table used for revenue reporting, trend analysis, and sales aggregation.

### Columns

| Column | Purpose | Example values |
|---|---|---|
| `order_number` | Sales order number | SO43697, SO43698 |
| `product_key` | Foreign key to `gold.dim_products` | 1, 2, 10 |
| `customer_key` | Foreign key to `gold.dim_customers` | 1, 2, 15 |
| `order_date` | Order date for the transaction | 2010-12-29 |
| `shipping_date` | Shipment date | 2011-01-05 |
| `due_date` | Payment due date | 2011-01-10 |
| `sales` | Sales amount for the order | 3578, 3400 |
| `quantity` | Number of units sold | 1 |
| `price` | Unit selling price | 3578, 699 |

### Example rows

```sql
SELECT TOP 5 *
FROM gold.fact_sales;
```

Example output:

| order_number | product_key | customer_key | order_date | shipping_date | due_date | sales | quantity | price |
|---|---:|---:|---|---|---|---:|---:|---:|
| SO43697 | 10 | 25 | 2010-12-29 | 2011-01-05 | 2011-01-10 | 3578 | 1 | 3578 |
| SO43698 | 11 | 40 | 2010-12-29 | 2011-01-05 | 2011-01-10 | 3400 | 1 | 3400 |
| SO43699 | 12 | 18 | 2010-12-29 | 2011-01-05 | 2011-01-10 | 3400 | 1 | 3400 |

### Business logic used
- The fact table joins the raw sales records to the customer and product dimensions using surrogate keys.
- `product_key` and `customer_key` are used instead of raw source IDs to create a clean star-schema design.
- Sales data is kept in transaction form for summaries, trend analysis, and revenue reporting.

---

## 5. Relationship Between the Gold Views

The gold layer follows a classic star schema pattern:

- `gold.dim_customers` contains customer attributes
- `gold.dim_products` contains product attributes
- `gold.fact_sales` stores transactional sales events and references both dimensions through surrogate keys

This design makes reporting and analysis easier because BI tools can query a fact table and join directly to the relevant dimensions.

---

## 6. Summary

The gold layer is the business-ready layer of the warehouse. It turns raw and cleaned data into a clean analytical model with:

- business-friendly column names
- standardized values
- surrogate keys for joins
- a star-schema structure for reporting

This enables dashboards, KPIs, and analytical queries without exposing the complexity of the raw source systems.
