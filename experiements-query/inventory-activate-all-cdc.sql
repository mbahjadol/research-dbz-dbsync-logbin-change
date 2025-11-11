USE [inventory];
GO

-- Aktifkan CDC di level database
EXEC sys.sp_cdc_enable_db;
GO

-- Aktifkan CDC di level tabel
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql += '
EXEC sys.sp_cdc_enable_table
     @source_schema = N''' + s.name + ''',
     @source_name   = N''' + t.name + ''',
     @role_name     = NULL;'
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE is_tracked_by_cdc = 0  -- hanya tabel yang belum aktif CDC

IF LEN(@sql) > 0
BEGIN
    PRINT '>> Mengaktifkan CDC pada tabel:';
    EXEC sp_executesql @sql;
END
ELSE
BEGIN
    PRINT '>> Semua tabel sudah aktif CDC.';
END
GO