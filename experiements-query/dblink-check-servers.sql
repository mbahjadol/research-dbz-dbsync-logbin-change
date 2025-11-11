-- SELECT name FROM TARGET_DB.master.sys.databases;
EXEC sp_linkedservers;


SELECT name FROM sys.servers WHERE is_linked = 1;
