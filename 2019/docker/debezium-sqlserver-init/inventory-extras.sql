-- Create the test database
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
-- Create and populate our products using a single insert with many rows
----------------------------------------------------
CREATE TABLE products (
  id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description VARCHAR(512),
  weight FLOAT
);
INSERT INTO products(name,description,weight)
  VALUES ('scooter','Small 2-wheel scooter',3.14);
INSERT INTO products(name,description,weight)
  VALUES ('car battery','12V car battery',8.1);
INSERT INTO products(name,description,weight)
  VALUES ('12-pack drill bits','12-pack of drill bits with sizes ranging from #40 to #3',0.8);
INSERT INTO products(name,description,weight)
  VALUES ('hammer','12oz carpenter''s hammer',0.75);
INSERT INTO products(name,description,weight)
  VALUES ('hammer','14oz carpenter''s hammer',0.875);
INSERT INTO products(name,description,weight)
  VALUES ('hammer','16oz carpenter''s hammer',1.0);
INSERT INTO products(name,description,weight)
  VALUES ('rocks','box of assorted rocks',5.3);
INSERT INTO products(name,description,weight)
  VALUES ('jacket','water resistent black wind breaker',0.1);
INSERT INTO products(name,description,weight)
  VALUES ('spare tire','24 inch spare tire',22.2);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'products', @role_name = NULL, @supports_net_changes = 0;


----------------------------------------------------
-- Create and populate the products on hand using multiple inserts
----------------------------------------------------
CREATE TABLE products_on_hand (
  product_id INTEGER NOT NULL PRIMARY KEY,
  quantity INTEGER NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products(id)
);
INSERT INTO products_on_hand(product_id,quantity) VALUES (1,3);
INSERT INTO products_on_hand(product_id,quantity) VALUES (2,8);
INSERT INTO products_on_hand(product_id,quantity) VALUES (3,18);
INSERT INTO products_on_hand(product_id,quantity) VALUES (4,4);
INSERT INTO products_on_hand(product_id,quantity) VALUES (5,5);
INSERT INTO products_on_hand(product_id,quantity) VALUES (6,0);
INSERT INTO products_on_hand(product_id,quantity) VALUES (7,44);
INSERT INTO products_on_hand(product_id,quantity) VALUES (8,2);
INSERT INTO products_on_hand(product_id,quantity) VALUES (9,5);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'products_on_hand', @role_name = NULL, @supports_net_changes = 0;

----------------------------------------------------
-- Create some customers ...
----------------------------------------------------
CREATE TABLE customers (
  id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
);
INSERT INTO customers(first_name,last_name,email)
  VALUES ('Sally','Thomas','sally.thomas@acme.com');
INSERT INTO customers(first_name,last_name,email)
  VALUES ('George','Bailey','gbailey@foobar.com');
INSERT INTO customers(first_name,last_name,email)
  VALUES ('Edward','Walker','ed@walker.com');
INSERT INTO customers(first_name,last_name,email)
  VALUES ('Anne','Kretchmar','annek@noanswer.org');
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'customers', @role_name = NULL, @supports_net_changes = 0;

----------------------------------------------------
-- Create some very simple orders
----------------------------------------------------
CREATE TABLE orders (
  id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
  order_date DATE NOT NULL,
  purchaser INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  FOREIGN KEY (purchaser) REFERENCES customers(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
INSERT INTO orders(order_date,purchaser,quantity,product_id)
  VALUES ('16-JAN-2016', 1, 1, 2);
INSERT INTO orders(order_date,purchaser,quantity,product_id)
  VALUES ('17-JAN-2016', 2, 2, 5);
INSERT INTO orders(order_date,purchaser,quantity,product_id)
  VALUES ('19-FEB-2016', 2, 2, 6);
INSERT INTO orders(order_date,purchaser,quantity,product_id)
  VALUES ('21-FEB-2016', 3, 1, 7);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'orders', @role_name = NULL, @supports_net_changes = 0;
GO

----------------------------------------------------
-- Create dummy transactions table to generate some extra traffic to simulate a busy database
----------------------------------------------------
CREATE TABLE transactions (
  id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
  customer_id INTEGER NOT NULL,
  amount FLOAT NOT NULL,
  transaction_date DATETIME NOT NULL DEFAULT GETDATE()
);
INSERT INTO transactions(customer_id,amount)
  VALUES (3, 1337.50);
EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'transactions', @role_name = NULL, @supports_net_changes = 0;
GO

----------------------------------------------------
-- Create dummy table to simulate lag in sync process of large inserts
----------------------------------------------------
CREATE TABLE insert_lag (
  id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
  info VARCHAR(1024) NOT NULL
);
INSERT INTO insert_lag(info)
  VALUES ('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.');
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


----------------------------------------------------
-- Registering a linked server to the target database 
----------------------------------------------------
EXEC sp_addlinkedserver
    @server = N'target_db',
    @srvproduct = N'',  -- leave blank for SQL Server
    @provider = N'SQLNCLI',  -- or use SQLNCLI11 / MSOLEDBSQL depending on version
    @datasrc = N'target-db';  -- Docker hostname of target SQL Server
GO

EXEC sp_addlinkedsrvlogin
    @rmtsrvname = N'target_db',
    @useself = 'false',
    @locallogin = NULL,
    @rmtuser = N'sa',
    @rmtpassword = N'Password!';
GO
