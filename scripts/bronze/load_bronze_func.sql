-- Author: Mahmoud Hussein
-- Purpose: Define and execute the bronze-layer loading procedure for the CRM and ERP datasets.
--          This script drops and recreates the bronze raw tables, then truncates and bulk-loads
--          the CSV source files into the DataWarehouse bronze schema.

create or alter PROCEDURE bronze.load_bronze as 
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME;
    DECLARE @start_time_batch DATETIME , @end_time_batch DATETIME
    DECLARE @error_message NVARCHAR(4000);

    -- setting the start time for loading the whole batch
    set @start_time_batch = GETDATE()
    BEGIN TRY
        PRINT '=====================================================================';
        PRINT 'loading bronze layer ';
        PRINT '=====================================================================';

        PRINT 'loading from crm source';
        PRINT '---------------------------------------------------------------------';

        SET @start_time = GETDATE(); 
        TRUNCATE TABLE bronze.crm_cust_info;
        BULK INSERT bronze.crm_cust_info
        FROM 'D:\Data Engineering\DWH_project\Data-Warehouse-Project\databases\source_crm\cust_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',', -- this tells the sql server the separator used inside the csv file
            TABLOCK -- this make the sql server lock the table while the bulk insert process happens
        );
        SET @end_time = GETDATE();
        PRINT 'the loading duration of the crm_cust_info ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.crm_prd_info;
        BULK INSERT bronze.crm_prd_info
        FROM 'D:\Data Engineering\DWH_project\Data-Warehouse-Project\databases\source_crm\prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK 
        );
        SET @end_time = GETDATE();
        PRINT 'the loading duration of the crm_prd_info ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.crm_sales_details;
        BULK INSERT bronze.crm_sales_details
        FROM 'D:\Data Engineering\DWH_project\Data-Warehouse-Project\databases\source_crm\sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT 'the loading duration of the crm_sales_details ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';
 
        PRINT '--------------------------------------------------------------------------------';
        PRINT 'loading from erp source';
        PRINT '--------------------------------------------------------------------------------';
    
        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.erp_cust_az12;
        BULK INSERT bronze.erp_cust_az12
        FROM 'D:\Data Engineering\DWH_project\Data-Warehouse-Project\databases\source_erp\CUST_AZ12.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT 'the loading duration of the erp_cust_az12 ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';
 
        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.erp_loc_a101;
        BULK INSERT bronze.erp_loc_a101
        FROM 'D:\Data Engineering\DWH_project\Data-Warehouse-Project\databases\source_erp\LOC_A101.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT 'the loading duration of the erp_loc_a101 ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';

        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'D:\Data Engineering\DWH_project\Data-Warehouse-Project\databases\source_erp\PX_CAT_G1V2.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT 'the loading duration of the erp_px_cat_g1v2 ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------------';
        SET @end_time_batch = GETDATE();
        PRINT 'the whole bronze batch duration = '+cast(datediff(SECOND ,@start_time_batch ,@end_time_batch) as VARCHAR) + ' seconds'
    END TRY
    BEGIN CATCH
        SET @error_message = ERROR_MESSAGE();
        PRINT '=====================================================================';
        PRINT 'Bronze load failed!';
        PRINT 'Error details: ' + @error_message;
        PRINT 'Error number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
        PRINT 'Error severity: ' + CAST(ERROR_SEVERITY() AS NVARCHAR(10));
        PRINT 'Error state: ' + CAST(ERROR_STATE() AS NVARCHAR(10));
        PRINT 'Procedure: bronze.load_bronze';
        PRINT '=====================================================================';
    END CATCH

END

-- try this stored procedure
exec bronze.load_bronze