USE [inventory];
GO
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql += '
EXEC sys.sp_cdc_disable_table
     @source_schema = N''' + s.name + ''',
     @source_name   = N''' + t.name + ''',
     @capture_instance = N''' + c.capture_instance + ''';'
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN cdc.change_tables c
  ON c.source_object_id = t.object_id
WHERE is_tracked_by_cdc = 1;

IF LEN(@sql) > 0
BEGIN
    PRINT '>> Menonaktifkan CDC pada tabel:';
    EXEC sp_executesql @sql;
END
ELSE
BEGIN
    PRINT '>> Tidak ada tabel dengan CDC aktif.';
END
GO
