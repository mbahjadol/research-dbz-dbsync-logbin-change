DECLARE @cutoff_lsn binary(10);
SET @cutoff_lsn = sys.fn_cdc_get_max_lsn();  -- or slightly before it
EXEC sys.sp_cdc_cleanup_change_table 
    @capture_instance = 'dbo_insert_lag',
    @low_water_mark = @cutoff_lsn;
