USE inventory;
GO

DECLARE @ci NVARCHAR(128);
DECLARE c CURSOR FOR
SELECT capture_instance FROM cdc.change_tables;

IF OBJECT_ID('tempdb..#baseline_compare') IS NOT NULL
    DROP TABLE #baseline_compare;

CREATE TABLE #baseline_compare (
    capture_instance NVARCHAR(128),
    table_name NVARCHAR(256),
    source_count BIGINT,
    target_count BIGINT,
    source_checksum BIGINT,
    target_checksum BIGINT,
    diff_count BIGINT,
    diff_checksum NVARCHAR(10)
);

OPEN c;
FETCH NEXT FROM c INTO @ci;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @schema NVARCHAR(128);
    DECLARE @table NVARCHAR(128);
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @src_cnt BIGINT;
    DECLARE @src_chk BIGINT;
    DECLARE @tgt_cnt BIGINT;
    DECLARE @tgt_chk BIGINT;
		
		DECLARE @DBLINK_SVR NVARCHAR(50);
		DECLARE @DB_NAME_BOTH NVARCHAR(50);

		SET @DBLINK_SVR = 'target_db';
		SET @DB_NAME_BOTH = 'inventory';
		

    SELECT 
        @schema = OBJECT_SCHEMA_NAME(source_object_id),
        @table  = OBJECT_NAME(source_object_id)
    FROM cdc.change_tables
    WHERE capture_instance = @ci;

    -- Source side
    SET @sql = N'SELECT @cnt_out = COUNT(*), @chk_out = CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM ' 
             + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N';';
    EXEC sp_executesql @sql, 
        N'@cnt_out BIGINT OUTPUT, @chk_out BIGINT OUTPUT', 
        @cnt_out=@src_cnt OUTPUT, 
        @chk_out=@src_chk OUTPUT;

    -- Target side via linked server
    SET @sql = N'SELECT @cnt_out = COUNT(*), @chk_out = CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM ' +
		 @DBLINK_SVR + '.' + @DB_NAME_BOTH + '.' 
             + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N';';
    EXEC sp_executesql @sql, 
        N'@cnt_out BIGINT OUTPUT, @chk_out BIGINT OUTPUT', 
        @cnt_out=@tgt_cnt OUTPUT, 
        @chk_out=@tgt_chk OUTPUT;

    INSERT INTO #baseline_compare
    SELECT 
        @ci, 
        @schema + '.' + @table,
        @src_cnt, @tgt_cnt, 
        @src_chk, @tgt_chk,
        @src_cnt - @tgt_cnt,
        CASE WHEN @src_chk = @tgt_chk THEN 'OK' ELSE 'DIFF' END;

    FETCH NEXT FROM c INTO @ci;
END

CLOSE c;
DEALLOCATE c;

SELECT * FROM #baseline_compare 
	where table_name IN ('dbo.insert_lag', 'dbo.update_lag')
ORDER BY table_name	;
	
DROP TABLE #baseline_compare;
GO
