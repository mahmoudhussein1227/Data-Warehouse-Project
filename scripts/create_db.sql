-- lets create schemas for the datawarehouse arch. different stages
use master ;
IF EXISTS (SELECT 1 from sys.databases WHERE name = 'DataWarehouse')
BEGIN
    alter database DataWarehouse set SINGLE_USER with ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;

end;

Go 

CREATE DATABASE DataWarehouse;
Go
use DataWarehouse;
Go
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO