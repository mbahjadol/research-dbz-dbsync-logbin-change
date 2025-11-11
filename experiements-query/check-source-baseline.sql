USE inventory;
GO

-- 1️⃣ Show all CDC-enabled tables
SELECT 
    capture_instance,
    OBJECT_SCHEMA_NAME(source_object_id) AS source_schema,
    OBJECT_NAME(source_object_id) AS source_table
FROM cdc.change_tables;
GO

-- 2️⃣ Baseline summary (LSN + counts + checksum)
DECLARE @ci NVARCHAR(128);
DECLARE c CURSOR FOR
SELECT capture_instance FROM cdc.change_tables;

CREATE TABLE #baseline_summary (
    capture_instance NVARCHAR(128),
    source_table NVARCHAR(256),
    min_lsn_hex NVARCHAR(50),
    max_lsn_hex NVARCHAR(50),
    row_count BIGINT,
    checksum BIGINT
);

OPEN c;
FETCH NEXT FROM c INTO @ci;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @schema NVARCHAR(128);
    DECLARE @table NVARCHAR(128);
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @min_lsn VARBINARY(10);
    DECLARE @max_lsn VARBINARY(10);
    DECLARE @min_lsn_hex NVARCHAR(50);
    DECLARE @max_lsn_hex NVARCHAR(50);
    DECLARE @cnt BIGINT;
    DECLARE @chk BIGINT;

    SELECT 
        @schema = OBJECT_SCHEMA_NAME(source_object_id),
        @table  = OBJECT_NAME(source_object_id)
    FROM cdc.change_tables
    WHERE capture_instance = @ci;

    SELECT 
        @min_lsn = sys.fn_cdc_get_min_lsn(@ci),
        @max_lsn = sys.fn_cdc_get_max_lsn();

    SELECT 
        @min_lsn_hex = sys.fn_varbintohexstr(@min_lsn),
        @max_lsn_hex = sys.fn_varbintohexstr(@max_lsn);

    SET @sql = N'SELECT @cnt_out = COUNT(*), @chk_out = CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM ' 
             + QUOTENAME(@schema) + N'.' + QUOTENAME(@table) + N';';

    EXEC sp_executesql @sql, 
        N'@cnt_out BIGINT OUTPUT, @chk_out BIGINT OUTPUT', 
        @cnt_out=@cnt OUTPUT, 
        @chk_out=@chk OUTPUT;

    INSERT INTO #baseline_summary
    SELECT @ci, @schema + '.' + @table, @min_lsn_hex, @max_lsn_hex, @cnt, @chk;

    FETCH NEXT FROM c INTO @ci;
END

CLOSE c;
DEALLOCATE c;

SELECT * FROM #baseline_summary ORDER BY source_table;
DROP TABLE #baseline_summary;
GO
