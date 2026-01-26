----------------------------------------------------
-- Create the test database
----------------------------------------------------
CREATE DATABASE inventory;
GO
ALTER DATABASE inventory
SET ALLOW_SNAPSHOT_ISOLATION ON;
GO
ALTER DATABASE inventory
SET READ_COMMITTED_SNAPSHOT ON;
GO
USE inventory;
EXEC sys.sp_cdc_enable_db;

----------------------------------------------------
-- Create table products
----------------------------------------------------
CREATE TABLE products (
  id INTEGER IDENTITY(101,1) NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description VARCHAR(512),
  weight FLOAT
);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'products', @role_name = NULL, @supports_net_changes = 0;

----------------------------------------------------
-- Create table products_on_hand
----------------------------------------------------
CREATE TABLE products_on_hand (
  product_id INTEGER NOT NULL PRIMARY KEY,
  quantity INTEGER NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products(id)
);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'products_on_hand', @role_name = NULL, @supports_net_changes = 0;

----------------------------------------------------
-- Create table customers 
----------------------------------------------------
CREATE TABLE customers (
  id INTEGER IDENTITY(1001,1) NOT NULL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'customers', @role_name = NULL, @supports_net_changes = 0;

----------------------------------------------------
-- Create table orders
----------------------------------------------------
CREATE TABLE orders (
  id INTEGER IDENTITY(10001,1) NOT NULL PRIMARY KEY,
  order_date DATE NOT NULL,
  purchaser INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  FOREIGN KEY (purchaser) REFERENCES customers(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'orders', @role_name = NULL, @supports_net_changes = 0;
GO


----------------------------------------------------
-- Create table transactions
----------------------------------------------------
CREATE TABLE transactions (
  id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
  customer_id INTEGER NOT NULL,
  amount FLOAT NOT NULL,
  transaction_date DATETIME NOT NULL DEFAULT GETDATE()
);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'transactions', @role_name = NULL, @supports_net_changes = 0;
GO

----------------------------------------------------
-- Create table insert_lag
----------------------------------------------------
CREATE TABLE insert_lag (
  id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
  info VARCHAR(1024) NOT NULL
);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'insert_lag', @role_name = NULL, @supports_net_changes = 0;
GO  

----------------------------------------------------
-- Create dummy table to simulate lag in sync process of large updates
----------------------------------------------------
CREATE TABLE update_lag (
  id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
  info VARCHAR(1024) NOT NULL
);
-- insert initial row for updates we prepare with 10,000 updates later
  --- 💡 CROSS JOIN multiplies rows: 2552 × 2552 = ~6.5 million rows, so TOP 10000 works fine here.
  INSERT INTO update_lag (info)
    SELECT TOP 10000 CONCAT('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis #', ROW_NUMBER() OVER (ORDER BY (SELECT NULL)))
    FROM master.dbo.spt_values a
    CROSS JOIN master.dbo.spt_values b;
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'update_lag', @role_name = NULL, @supports_net_changes = 0;
