-- 1) Switch to SIMPLE to truncate log (force)
ALTER DATABASE inventory SET RECOVERY SIMPLE WITH NO_WAIT;
GO
CHECKPOINT;
GO
-- 2) Shrink log file to free space (force truncation)
-- DBCC SHRINKFILE ('inventory_log', 1); -- use the logical log file name

DBCC SHRINKFILE ('inventory_log', TRUNCATEONLY);


GO
-- 3) Switch back to FULL if you need to resume full recovery model
ALTER DATABASE inventory SET RECOVERY FULL;
GO


-- 4) (Recommended) Take a full backup to re-establish the log chain
BACKUP DATABASE inventory TO DISK = '/var/opt/mssql/backup/inventory.bak';
GO
