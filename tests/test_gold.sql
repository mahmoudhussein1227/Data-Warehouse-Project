-- objective : is to create the bussiness objects


-- create the customers object
-- check dups introduced by the joins -> no dups added
-- check matching between the diff sources same info like gender -> exisits 
    -- solution is to rely on the info from the master table which is the crm on (ci)

-- adjust the names to be friendly names and group the relavnet information together
-- then decide which is dim or fact object -> dim for customers
-- add surrget key to be used for data joins and building the star schema and don't depend on the id from the sources
-- then create the view

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
    ci.cst_create_date
from silver.crm_cust_info as ci
LEFT JOIN silver.erp_cust_az12 as ca
on ci.cst_key = ca.cid
LEFT join silver.erp_loc_a101 as cl
on ci.cst_key = cl.cid

-- tests

-- check that the new gen follow only the master table from crm
SELECT * from (
select
    ci.cst_id,
    ci.cst_gndr,
    ca.gen,
    case when ci.cst_gndr != 'n/a' then ci.cst_gndr
    else COALESCE(ca.gen , 'n/a')
    end new_gen
from silver.crm_cust_info as ci
LEFT JOIN silver.erp_cust_az12 as ca
on ci.cst_key = ca.cid
LEFT join silver.erp_loc_a101 as cl
on ci.cst_key = cl.cid

)t 
WHERE cst_id = 11022 and new_gen != cst_gndr

select distinct gender from gold.dim_customers
----------------------------------------------------------------------------------

-- product object 

-- first we need to remove history info
-- then add surrget key
-- group relavent info together
-- decide wether dim or fact

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

----------------------------------------------------------------------------------------------
-- our sales table is our containg transactional records 
-- so it is a fact table
-- first thing to do in the query of the fact tables is to bring the surrget keys from all dim tables
-- which is known as lookup 

CREATE VIEW gold.fact_sales as
SELECT 
    sd.sls_ord_num as order_number ,
    pi.product_key, -- second surrgot key lookup
    c.customer_key, -- first surrgot key lookup
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


-- test to join the dim with the fact using the new surrgot keys

SELECT * from gold.fact_sales as s
LEFT JOIN gold.dim_customers as c
on c.customer_key = s.customer_key
LEFT JOIN gold.dim_products as p
on p.product_key = s.product_key

where c.customer_id is null or p.product_key is null
-- safe all sales products and sales customers are inside the dims and all dims can safely be joind with the fact using the surrgot keys 