USE inventory;
-- Danger: will remove older change rows for capture instance
EXEC sys.sp_cdc_cleanup_change_table @capture_instance = N'dbo.update_lag', @low_water_mark = NULL, @threshold = 5000;
-- or specify a low_water_mark LSN to cleanup up to that LSN