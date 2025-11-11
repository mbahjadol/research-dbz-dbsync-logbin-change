-- 
-- FULL: Requires log backups; supports point-in-time recovery.
-- SIMPLE: Log space is reclaimed automatically; no log backups.
-- BULK_LOGGED: Minimal logging for bulk operations; requires log backups.
-- 
SELECT 
    name AS DatabaseName,
    recovery_model_desc AS RecoveryModel
FROM sys.databases
WHERE name = DB_NAME();  -- current database

