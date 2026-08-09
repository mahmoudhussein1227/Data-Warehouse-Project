# Data-Warehouse-Project

This repository implements a SQL Server data warehouse using the medallion architecture.

## Overview
The project follows a layered approach:
- Bronze: raw and unchanged source data copied into the warehouse
- Silver: cleaned, standardized, and validated data
- Gold: business-ready analytical tables for reporting and BI

## Bronze Layer
The bronze layer is the foundation of the warehouse. Its purpose is to preserve an exact or near-exact copy of the raw source data as it arrives from the CRM and ERP systems.

This layer is used for:
- tracing source values back to original files
- keeping a reliable snapshot before transformations
- supporting reprocessing when cleaning rules change
- acting as source of row data in case of debugging or comsuming from the upper layer

In this project, the bronze schema stores the raw CSV-based source data in tables such as:
- crm_cust_info
- crm_prd_info
- crm_sales_details
- erp_cust_az12
- erp_loc_a101
- erp_px_cat_g1v2


## Bronze Layer Diagram
![Bronze layer architecture](draws/bronze_layer.drawio)

The diagram in the draws folder shows the bronze layer as the raw ingestion area where CRM and ERP source data is stored before any cleaning or business-level transformations are applied.

The bronze tables are intentionally kept close to the source structure, with no transformations and no data modeling so that downstream silver and gold layers can be built from a trusted raw foundation.


