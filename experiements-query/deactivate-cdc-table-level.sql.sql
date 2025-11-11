EXEC sys.sp_cdc_disable_table
    @source_schema = N'dbo',
    @source_name = N'log_insert',
    @capture_instance = N'dbo_log_insert';