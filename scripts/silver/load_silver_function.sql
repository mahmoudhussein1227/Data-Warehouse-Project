-- Author: Mahmoud Hussein
-- Purpose: Load and transform the raw bronze data into the silver layer.
--          This procedure performs cleaning, normalization, validation, and deduplication
--          for CRM and ERP source tables before storing the curated data in the silver schema.

CREATE OR ALTER PROCEDURE silver.load_silver AS 
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME;
    Declare @start_time_batch DATETIME , @end_time_batch DATETIME
    DECLARE @error_message NVARCHAR(4000);

    set @start_time_batch = GETDATE()
    BEGIN TRY
        PRINT '=====================================================================';
        PRINT 'loading silver layer';
        PRINT '=====================================================================';

        PRINT 'loading from bronze layer';
        PRINT '---------------------------------------------------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.crm_cust_info;
        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,
            CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                 WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                 ELSE 'n/a'
            END AS cst_marital_status,
            CASE WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                 WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                 ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS recent_flag
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t
        WHERE recent_flag = 1;
        SET @end_time = GETDATE();
        PRINT 'the loadind duration of the silver.crm_cust_info ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.crm_prd_info;
        INSERT INTO silver.crm_prd_info (
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
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
            prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,
            CASE UPPER(prd_line)
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
        FROM bronze.crm_prd_info;
        SET @end_time = GETDATE();
        PRINT 'the loadind duration of the silver.crm_prd_info ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.crm_sales_details;
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE WHEN LEN(sls_order_dt) != 8 OR sls_order_dt <= 0 THEN NULL
                 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            CASE WHEN LEN(sls_ship_dt) != 8 OR sls_ship_dt <= 0 THEN NULL
                 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            CASE WHEN LEN(sls_due_dt) != 8 OR sls_due_dt <= 0 THEN NULL
                 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            CASE WHEN sls_sales IS NULL OR sls_sales <= 0 THEN sls_quantity * ABS(sls_price)
                 ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            CASE WHEN sls_price IS NULL OR sls_price <= 0 THEN sls_sales / NULLIF(sls_quantity, 0)
                 ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details;
        SET @end_time = GETDATE();
        PRINT 'the loadind duration of the silver.crm_sales_details ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        PRINT '--------------------------------------------------------------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.erp_cust_az12;
        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                 ELSE cid
            END AS cid,
            CASE WHEN bdate > GETDATE() THEN NULL
                 ELSE bdate
            END AS bdate,
            CASE 
                WHEN UPPER(TRIM(gen)) IN ('M', 'Male') THEN 'Male'
                WHEN UPPER(TRIM(gen)) IN ('F', 'Female') THEN 'Female'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;
        SET @end_time = GETDATE();
        PRINT 'the loadind duration of the silver.erp_cust_az12 ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.erp_loc_a101;
        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )
        SELECT
            CASE WHEN cid LIKE 'AW-%' THEN REPLACE(cid, '-', '')
                 ELSE cid
            END AS cid,
            CASE WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
                 WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
                 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
                 ELSE TRIM(cntry)
            END AS cntry
        FROM bronze.erp_loc_a101;
        SET @end_time = GETDATE();
        PRINT 'the loadind duration of the silver.erp_loc_a101 ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        INSERT INTO silver.erp_px_cat_g1v2 (
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
        FROM bronze.erp_px_cat_g1v2;
        SET @end_time = GETDATE();
        PRINT 'the loadind duration of the silver.erp_px_cat_g1v2 ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        set @end_time_batch = GETDATE()
        PRINT 'total silver layer loading duration = ' + cast(DATEDIFF(SECOND , @start_time_batch , @end_time_batch) as VARCHAR) + ' seconds'
    END TRY
    BEGIN CATCH
        SET @error_message = ERROR_MESSAGE();
        PRINT '=====================================================================';
        PRINT 'Silver load failed!';
        PRINT 'Error details: ' + @error_message;
        PRINT 'Error number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
        PRINT 'Error severity: ' + CAST(ERROR_SEVERITY() AS NVARCHAR(10));
        PRINT 'Error state: ' + CAST(ERROR_STATE() AS NVARCHAR(10));
        PRINT 'Procedure: silver.load_silver';
        PRINT '=====================================================================';
    END CATCH
END


