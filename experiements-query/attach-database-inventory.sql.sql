use master;

/* ===== B. Attach kembali dengan REBUILD LOG (tanpa file .LDF) ===== */
/* Pastikan path .MDF & .NDF benar. Jika KICSERP hanya punya satu data file .MDF, cukup 1 baris ON. */
CREATE DATABASE [inventory]
ON (FILENAME = N'/var/opt/mssql/data/inventory.mdf')
-- ,(FILENAME = N'...KICSERP_2.ndf')  -- jika ada NDF, tambahkan di sini
FOR ATTACH_REBUILD_LOG;
GO

/* ===== C. (Opsional tapi disarankan) Pindahkan log hasil rebuild ke lokasi final Anda ===== */
-- Cek logical name & lokasi log yang baru dibuat
SELECT name, type_desc, physical_name
FROM [inventory].sys.database_files
WHERE type_desc = 'LOG';

-- -- Misal Anda ingin path final: C:\SQL2022Node1\DB_LOG\KICSERP_log.ldf
-- -- (ganti FILENAME sesuai kebijakan path/drive Anda)
--ALTER DATABASE [inventory]
--  MODIFY FILE (NAME = N'KICSERP_log', FILENAME = N'C:\SQL2022Node1\DB_LOG\KICSERP_log.ldf');
--GO

-- -- OFFLINE → pindahkan file fisik .LDF sesuai FILENAME → ONLINE
-- ALTER DATABASE [inventory] SET OFFLINE WITH ROLLBACK IMMEDIATE;
-- -- (Langkah OS: pastikan file .LDF berada di C:\SQL2022Node1\DB_LOG\ sesuai FILENAME di atas)
ALTER DATABASE [inventory] SET ONLINE;
GO

-- /* ===== D. Right-size & kebijakan growth untuk log baru ===== */
-- -- Contoh: ukuran awal 8 GB, growth 512 MB (fixed, bukan persen)
-- ALTER DATABASE [inventory]
--   MODIFY FILE (NAME = N'inventory_log', SIZE = 8192MB, FILEGROWTH = 512MB);
-- GO
-- 
/* ===== E. Kembalikan ke FULL & buat FULL backup (start log chain baru) ===== */
ALTER DATABASE [inventory] SET MULTI_USER;   -- kembali ke multi user
ALTER DATABASE [inventory] SET RECOVERY FULL;
GO
