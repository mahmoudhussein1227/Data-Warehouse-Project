-- lets create schemas for the datawarehouse arch. different stages
CREATE DATABASE DataWarhouse;
Go
use DataWarehouse;
Go
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO