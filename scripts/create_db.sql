-- Author: Mahmoud Hussein
-- Purpose: Create the DataWarehouse database and initialize the bronze, silver, and gold schemas
-- for a staged data warehouse architecture.

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