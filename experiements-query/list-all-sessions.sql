SELECT
    s.session_id,
		s.host_name,
    c.client_net_address AS client_ip,
    s.login_name,
    s.program_name
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON s.session_id = c.session_id
WHERE s.database_id = DB_ID('inventory');



-- select * FROM sys.dm_exec_connections;
-- 
-- select * from sys.dm_exec_sessions;