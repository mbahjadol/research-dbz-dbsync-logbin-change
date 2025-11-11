SELECT 
    [Current LSN], 
    [Transaction ID], 
    [Operation], 
    [Transaction Name], 
    [Transaction SID]
FROM fn_dblog(NULL, NULL);