USE YourDB;
EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = N'update_lag', @capture_instance = N'dbo.update_lag';
-- or for database:
EXEC sys.sp_cdc_disable_db;
