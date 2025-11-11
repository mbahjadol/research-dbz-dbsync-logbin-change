SELECT name AS LogicalFileName, type_desc, physical_name
FROM sys.database_files
WHERE type_desc = 'LOG';