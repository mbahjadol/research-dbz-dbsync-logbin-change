EXEC sp_addlinkedserver
    @server = N'target_db',
    @srvproduct = N'',  -- leave blank for SQL Server
    @provider = N'SQLNCLI',  -- or use SQLNCLI11 / MSOLEDBSQL depending on version
    @datasrc = N'target-db';  -- Docker hostname of target SQL Server
GO


EXEC sp_addlinkedsrvlogin
    @rmtsrvname = N'target_db',
    @useself = 'false',
    @locallogin = NULL,
    @rmtuser = N'sa',
    @rmtpassword = N'Password!';
GO

-- -- SELECT name FROM TARGET_DB.master.sys.databases;

