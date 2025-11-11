EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'insert_lag',
    @role_name = NULL;
		
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'update_lag',
    @role_name = NULL;
		