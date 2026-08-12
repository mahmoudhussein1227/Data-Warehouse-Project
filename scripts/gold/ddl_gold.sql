-- objective : is to create the bussiness objects 
          -- : create the the views and the data model in star schema fashion
          -- : fact table will be the sales and the products and customers will be the dims
          -- : object types are view for dynamic and always fresh query results

-- gold_dim_customers view

-- rely on the info from the master table which is the crm on (ci)
-- adjust the names to be friendly names and group the relavnet information together
-- add surrogate key to be used for data joins and building the star schema and don't depend on the id from the sources

CREATE VIEW gold.dim_customers as
select
    ROW_NUMBER()over(order by ci.cst_id) as customer_key,
    ci.cst_id as customer_id,
    ci.cst_key as customer_number,
    ci.cst_firstname as first_name,
    ci.cst_lastname as last_name,
    cl.cntry as country,
    case when ci.cst_gndr != 'n/a' then ci.cst_gndr
    else COALESCE(ca.gen , 'n/a')
    end gender,
    ci.cst_marital_status as marital_status,
    ca.bdate as birth_date,
    ci.cst_create_date as create_date
from silver.crm_cust_info as ci
LEFT JOIN silver.erp_cust_az12 as ca
on ci.cst_key = ca.cid
LEFT join silver.erp_loc_a101 as cl
on ci.cst_key = cl.cid

-- gold_dim_products

-- first we need to remove history info
-- then add surrget key
-- group relavent info together

create VIEW gold.dim_products as 
select
    ROW_NUMBER()over(order by pi.prd_id , pi.prd_start_dt ) as product_key,
    pi.prd_id as product_id,
    pi.cat_id as category_id,
    pi.prd_key as product_number,
    pi.prd_nm as product_name,
    pc.cat as category,
    pc.subcat as subcategory,
    pc.maintenance as maintenance,
    pi.prd_cost as cost,
    pi.prd_line as line,
    pi.prd_start_dt as start_date   

from silver.crm_prd_info as pi
LEFT join silver.erp_px_cat_g1v2 as pc
on pi.cat_id = pc.id
WHERE pi.prd_end_dt is null


--gold_fact_sales

--our sales table is our containg transactional records 
-- so it is a fact table
-- first thing to do in the query of the fact tables is to bring the surrogate  keys from all dim tables
-- which is known as lookup 

CREATE VIEW gold.fact_sales as
SELECT 
    sd.sls_ord_num as order_number ,
    pi.product_key, -- second surrogate  key lookup
    c.customer_key, -- first surrogate  key lookup
    sd.sls_order_dt as order_date,
    sd.sls_ship_dt as shipping_date,
    sd.sls_due_dt as due_date,
    sd.sls_sales as sales,
    sd.sls_quantity as quantity,
    sd.sls_price as price

from silver.crm_sales_details as sd
LEFT join gold.dim_customers as c
on c.customer_id = sd.sls_cust_id
LEFT JOIN gold.dim_products as pi
on pi.product_number = sd.sls_prd_key