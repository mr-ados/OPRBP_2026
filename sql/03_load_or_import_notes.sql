/*
    UFC_OPRBP - 03_load_or_import_notes.sql
    Imports CSV files from data/raw into staging tables.

    If BULK INSERT reports a file permission error, use SSMS Import Flat File Wizard
    into the same stg.* tables, or move the CSV files to a SQL Server-readable folder.
*/
USE UFC_OPRBP;
GO
SET NOCOUNT ON;
GO

DECLARE @RawDataPath NVARCHAR(4000) = N'C:\SQLImport\UFC\';
DECLARE @FilePath NVARCHAR(4000);
DECLARE @Sql NVARCHAR(MAX);

TRUNCATE TABLE stg.EventDetails;
TRUNCATE TABLE stg.FightDetails;
TRUNCATE TABLE stg.FighterDetails;
TRUNCATE TABLE stg.UFCMaster;


SET @FilePath = @RawDataPath + N'event_details.csv';
SET @Sql = N'
BULK INSERT stg.EventDetails
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK,
    KEEPNULLS
);';
EXEC sys.sp_executesql @Sql;
PRINT 'event_details.csv imported into stg.EventDetails';


SET @FilePath = @RawDataPath + N'fighter_details.csv';
SET @Sql = N'
BULK INSERT stg.FighterDetails
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK,
    KEEPNULLS
);';
EXEC sys.sp_executesql @Sql;
PRINT 'fighter_details.csv imported into stg.FighterDetails';


SET @FilePath = @RawDataPath + N'fight_details.csv';
SET @Sql = N'
BULK INSERT stg.FightDetails
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK,
    KEEPNULLS
);';
EXEC sys.sp_executesql @Sql;
PRINT 'fight_details.csv imported into stg.FightDetails';


SET @FilePath = @RawDataPath + N'UFC.csv';
SET @Sql = N'
BULK INSERT stg.UFCMaster
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK,
    KEEPNULLS
);';
EXEC sys.sp_executesql @Sql;
PRINT 'UFC.csv imported into stg.UFCMaster';


SELECT 'stg.EventDetails' AS table_name, COUNT(*) AS row_count FROM stg.EventDetails
UNION ALL SELECT 'stg.FighterDetails', COUNT(*) FROM stg.FighterDetails
UNION ALL SELECT 'stg.FightDetails', COUNT(*) FROM stg.FightDetails
UNION ALL SELECT 'stg.UFCMaster', COUNT(*) FROM stg.UFCMaster;
GO
