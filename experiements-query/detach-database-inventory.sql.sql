use master;

-- Pastikan tidak ada koneksi yang menahan
ALTER DATABASE [inventory] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO


BEGIN TRY
    USE [inventory];
    CHECKPOINT;
END TRY
BEGIN CATCH
    PRINT 'INFO: CHECKPOINT diabaikan.';
END CATCH
GO



-- Detach database
USE master;
EXEC sp_detach_db N'inventory';
GO

