/*
===============================================================================
Silver Layer Transformation Documentation
===============================================================================
This script documents the quality checks and transformations applied to move data
from the bronze layer into the silver layer.

Table-by-table summary:

1) crm_cust_info
   Issues found:
   - duplicate customer IDs (cst_id)
   - leading/trailing spaces in first and last names
   - inconsistent marital status values (S/M) and gender values (M/F)
   Transformation type:
   - trim name fields
   - normalize marital status and gender to friendly text values
   - keep only the most recent record per cst_id using ROW_NUMBER()

2) crm_prd_info
   Issues found:
   - null product costs
   - inconsistent product line codes (M/R/S/T)
   - prd_key needs to be split for matching with downstream tables
   Transformation type:
   - derive cat_id from the product key prefix
   - replace null cost with 0
   - normalize prd_line values to business labels
   - cast date columns to DATE
   - derive prd_end_dt as one day before the next product start date

3) crm_sales_details
   Issues found:
   - invalid or zero date values in order/ship/due dates
   - missing or invalid sales and price values
   - sales/price relationships need consistency checks
   Transformation type:
   - convert numeric date strings to DATE
   - set invalid dates to NULL
   - derive sales value when sales is null or <= 0
   - derive price value when price is null or <= 0

4) erp_cust_az12
   Issues found:
   - customer IDs prefixed with NAS
   - future birth dates
   - inconsistent gender values (M/F and Male/Female)
   Transformation type:
   - remove NAS prefix to align with CRM customer key format
   - replace future dates with NULL
   - standardize gender values to Male/Female or n/a

5) erp_loc_a101
   Issues found:
   - country codes need normalization
   - id format uses AW- prefix and hyphen separation
   Transformation type:
   - normalize country names (DE -> Germany, US/USA -> United States)
   - remove hyphen from AW IDs to match CRM key format
   - replace blank/null country values with n/a

6) erp_px_cat_g1v2
   Issues found:
   - category ID should align with crm_prd_info cat_id
   - possible whitespace inconsistencies
   Transformation type:
   - trim values and validate alignment with downstream dimensions
   - pass-through mapping with minimal transformation
===============================================================================
*/

-- this script is for doing data transformation for the crm_cust_info table

-- crm_cust_info_table

-- dups check in cst_id
-- expected : no result

SELECT cst_id , 
       COUNT(*)

from silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1

SELECT * FROM silver.crm_cust_info
WHERE cst_id = 29449

-- unwanted spaces checks
-- expected : no results
select cst_firstname from silver.crm_cust_info 
WHERE cst_firstname != TRIM((cst_firstname));

select cst_lastname from silver.crm_cust_info 
WHERE cst_lastname != TRIM((cst_firstname));

-- normalaization checks
SELECT distinct cst_marital_status from silver.crm_cust_info

SELECT distinct cst_gndr from silver.crm_cust_info


--- main query

insert into silver.crm_cust_info(
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date

)
SELECT
    cst_id ,
    cst_key,

    -- remove unwanted spaces
    trim(cst_firstname) as cst_firstname,
    trim(cst_lastname) as cst_lastname,

    -- doing data normalization to normalize the appriviation to friendly txt
    case when upper(TRIM(cst_marital_status)) = 'S' then 'Single'
         when upper(TRIM(cst_marital_status)) = 'M' then 'Married'
         else 'n/a'
    END as cst_marital_status,

    case when upper(TRIM(cst_gndr)) = 'M' then 'Male'
         when upper(TRIM(cst_gndr)) = 'F' then 'Female'
         else 'n/a'
    END as cst_gndr,

    cst_create_date

from (
    -- remove duplicates and nulls from the primary key cst_id
    -- use the most recent record
    SELECT
    *,
    ROW_NUMBER()OVER(PARTITION BY cst_id ORDER BY cst_create_date desc) as recent_flag
    from bronze.crm_cust_info
    where cst_id is not null

)t
WHERE recent_flag = 1 


---------------------------------------------------------------------------

--crm_prd_info table

SELECT * from silver.crm_prd_info

-- check dups and nulls in the primary key prd_id
-- this table has no dups in the prd_id col and no nulls 
SELECT COUNT(*) FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 or prd_id is NULL

-- split the prd_key to 2 extra col to me matched with the crm_sls_details table and erp_px_cat_g1v2
SELECT distinct sls_prd_key from bronze.crm_sales_details;
SELECT distinct prd_key from bronze.crm_prd_info;
SELECT distinct id from bronze.erp_px_cat_g1v2;

--check if the prd_key has an unwanted spaces
-- prd_key is perfect
SELECT * from silver.crm_prd_info 
WHERE prd_key != TRIM(prd_key)

-- checking that the sls_prd_key match the prd_key in crm_prd_info table
select distinct sls_prd_key
from bronze.crm_sales_details
WHERE sls_prd_key not in (select distinct prd_key  from silver.crm_prd_info)

-- check that there are no unwanted spaces in the prd_name 
-- prd_nm is perfect
SELECT prd_nm from silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)

-- check that no negative or null prd_cost 
-- there is a nulls only 
SELECT prd_cost from silver.crm_prd_info
where prd_cost is null or prd_cost < 0

-- check the normalization of the prd_line 
-- found nulls and some appriviations 
SELECT distinct prd_line from silver.crm_prd_info 

-- check that the startdate is always smaller than the enddate
-- in all records the startdate > enddate
select * from silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt

-- main query
INSERT into silver.crm_prd_info(
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
SELECT
    prd_id,

    -- derive new cols 
    replace(SUBSTRING(prd_key , 1 , 5) , '-' ,'_') as cat_id, -- CO_PE not fount in sales
    SUBSTRING(prd_key , 7 , len(prd_key)) as prd_key,

    prd_nm,

    -- convert nulls to zero in the cost
    ISNULL(prd_cost , 0) as prd_cost,

    -- data normalization
    case (UPPER(prd_line)) 
    WHEN 'M' THEN 'Mountain'
    WHEN 'R' THEN 'Road'
    WHEN 'S' THEN 'Other Sales'
    WHEN 'T' THEN 'Touring'
    else 'n/a'
    END as prd_line,

    -- no time info so convert datetime to the date type
    cast(prd_start_dt as date) as prd_start_dt,

    -- getting the enddate as one day before the next startdate of each product
    -- this is data enrichment
    cast(LEAD(prd_start_dt)OVER(PARTITION BY prd_key ORDER BY prd_start_dt) -1 as date ) as prd_end_dt

from bronze.crm_prd_info

--------------------------------------------------------------------------------
-- crm_sales_details table

SELECT * from bronze.crm_sales_details

-- check nulls and dups in the sls_ord_num or unwanted spaces
-- no there are no nulls or unwanted spaces
select
    sls_ord_num
from bronze.crm_sales_details
WHERE sls_ord_num is null or trim(sls_ord_num) != sls_ord_num 

-- check the correctance of the prd_key
-- all prd_keys in sales are in the prod table 
SELECT sls_prd_key from bronze.crm_sales_details
WHERE sls_prd_key not in (select distinct prd_key from silver.crm_prd_info)

-- check the correctace of the sls_cust_id
-- all customers from the sales are in the customer table
SELECT sls_cust_id from bronze.crm_sales_details
WHERE sls_cust_id not in (select distinct cst_id from silver.crm_cust_info)

-- check that no zero or negative dates or the startdate > due or ship dates
-- only the order_dt has problems
SELECT
    nullif(sls_order_dt , 0)
from bronze.crm_sales_details
WHERE len(sls_order_dt) != 8 or 
      sls_order_dt <= 0 

SELECT
    nullif(sls_ship_dt , 0)
from bronze.crm_sales_details
WHERE len(sls_ship_dt) != 8 or 
      sls_ship_dt <= 0 

SELECT
    nullif(sls_due_dt , 0)
from bronze.crm_sales_details
WHERE len(sls_due_dt) != 8 or 
      sls_due_dt <= 0 

select * from bronze.crm_sales_details 
where sls_order_dt > sls_ship_dt
      or sls_order_dt > sls_due_dt


-- check on sales equation
SELECT
    case when sls_sales is null or sls_sales <= 0  then sls_quantity * abs(sls_price)
    else sls_sales
    end sls_sales,

    case when sls_price is null or sls_price <= 0  then sls_sales / nullif(sls_quantity, 0)
    else sls_price
    end sls_price,

    sls_quantity
from bronze.crm_sales_details
    
where sls_sales is NULL OR
      sls_sales != sls_quantity * sls_price or
      sls_sales < 0 or 
      sls_price < 0 OR
      sls_quantity < 0 OR
      sls_quantity is null OR
      sls_price is null 

-- main query

insert into silver.crm_sales_details(
    sls_ord_num , 
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price

)
select 
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,

    case when len(sls_order_dt) != 8 or sls_order_dt <=0 then null 
    else cast(CAST(sls_order_dt as varchar) as date) 
    end as sls_order_dt,

    case when len(sls_ship_dt) != 8 or sls_ship_dt <=0 then null 
    else cast(CAST(sls_ship_dt as varchar) as date) 
    end as sls_ship_dt,

    case when len(sls_due_dt) != 8 or sls_due_dt <=0 then null 
    else cast(CAST(sls_due_dt as varchar) as date) 
    end as sls_due_dt,

    case when sls_sales is null or sls_sales <= 0  then sls_quantity * abs(sls_price)
    else sls_sales
    end sls_sales,

    sls_quantity,

    case when sls_price is null or sls_price <= 0  then sls_sales / nullif(sls_quantity, 0)
    else sls_price
    end sls_price



from bronze.crm_sales_details

select * from silver.crm_sales_details

-------------------------------------------------------------------------
-- erp_cust_az12 table

SELECT  * from bronze.erp_cust_az12
select distinct cst_key  from silver.crm_cust_info
where cst_key like 'NAS%'
-- checking quality of the date
select distinct bdate from silver.erp_cust_az12 
where bdate > GETDATE()

-- checking the standarization of the gen
SELECT distinct gen from silver.erp_cust_az12
--
/*
NULL
F 
  
Male
Female
M 
*/

-- check the unwanted spaces in gen

insert into silver.erp_cust_az12
(
    cid , 
    bdate,
    gen
)
select
    -- transform cid to be suitable for matching with the cst_key from the crm_cust_info
    case when cid like 'NAS%' then SUBSTRING(cid , 4 , LEN(cid))
    else cid
    end cid,

    -- clean the future dates replace it with null
    case when bdate > GETDATE() then null
    else bdate
    end bdate,

    -- standardize the gen col
    case 
    when UPPER(trim(gen)) in ('M' ,'Male')  then  'Male'
    when UPPER(trim(gen)) in ('F' ,'Female') then 'Female'
    else 'n/a'
    end gen

from bronze.erp_cust_az12

select * from silver.erp_cust_az12

------------------------------------------------------------------------------

-- erp_loc_a101

SELECT * from bronze.erp_loc_a101

-- cheking the cid keys
select distinct cid from silver.erp_loc_a101
WHERE cid  not in(select distinct cst_key from silver.crm_cust_info);

select distinct cst_key from bronze.crm_cust_info;
SELECT distinct cid from silver.erp_loc_a101

-- check the normalization of the cntry
select distinct cntry from silver.erp_loc_a101

-- main query
INSERT into silver.erp_loc_a101 (
    cid , 
    cntry
)
select 
    -- correcting the key
    case when cid like 'AW-%' then REPLACE(cid , '-' , '')
    else cid 
    end cid,

    -- doing data normalization 
    case when UPPER(TRIM(cntry)) = 'DE' then 'Germany'
         when UPPER(TRIM(cntry)) in ('US' , 'USA') then 'United States'
         when TRIM(cntry)  = ''  or cntry is null then 'n/a'
         else TRIM(cntry)
         end cntry
from bronze.erp_loc_a101

select * from silver.erp_loc_a101

---------------------------------------------------------------------------

-- erp_px_cat_g1v2

SELECT * from bronze.erp_px_cat_g1v2

-- id quality check 
-- it must be the same as the cat_key of the crm_prd_info

SELECT distinct id from bronze.erp_px_cat_g1v2
WHERE id not in (select distinct cat_id from silver.crm_prd_info )

-- check the standarization of the cat
select distinct cat from bronze.erp_px_cat_g1v2
-- check the unwanted spaces 
select cat from bronze.erp_px_cat_g1v2
where TRIM(cat) != cat

-- this table is perfect 

-- main query
insert into silver.erp_px_cat_g1v2(
    id,
    cat,
    subcat,
    maintenance
)
SELECT 
    id,
    cat,
    subcat,
    maintenance
from bronze.erp_px_cat_g1v2

select * from silver.erp_px_cat_g1v2