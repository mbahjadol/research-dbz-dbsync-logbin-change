SELECT 
    name AS LogicalName,
    type_desc AS FileType,
    size * 8 / 1024 AS SizeMB,
    physical_name AS FilePath
FROM sys.database_files
WHERE type_desc = 'LOG';
