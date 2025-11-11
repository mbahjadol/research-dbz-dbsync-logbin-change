-- CREATE TRIGGER limit_login_ip
-- ON ALL SERVER
-- FOR LOGON
-- AS
-- BEGIN
--     DECLARE @ip NVARCHAR(48);
--     SELECT @ip = client_net_address FROM sys.dm_exec_connections WHERE session_id = @@SPID;
-- 
--     IF @ip NOT IN ('172.25.0.5', '127.0.0.1')
--     BEGIN
--         PRINT 'Denied login from unauthorized IP: ' + @ip;
--         ROLLBACK;
--     END
-- END;
-- GO


DROP TRIGGER IF EXISTS block_login_hostname ON ALL SERVER;
GO

CREATE TRIGGER block_login_hostname
ON ALL SERVER 
FOR LOGON
AS
BEGIN
    DECLARE @hostname NVARCHAR(100);
    SELECT @hostname = host_name 
    FROM sys.dm_exec_sessions 
    WHERE session_id = @@SPID;

    IF @hostname IN ('sim-svc', 'testing-hostname')
    BEGIN
        PRINT 'Denied login from unauthorized host_name: ' + @hostname;
        ROLLBACK;
    END
END;
GO