/*
    UFC_OPRBP - 03_load_tsv_compatible.sql

    Use this instead of 03_load_or_import_notes.sql if BULK INSERT with
    FORMAT='CSV' fails with Msg 7301 / IID_IColumnsInfo.

    Steps:
    1) Run tools/prepare_tsv_for_sqlserver.py if TSV files do not exist.
    2) Copy data/processed/tsv/*.tsv to C:\SQLImport\UFC\.
    3) Make sure SQL Server service can read that folder.
    4) Run this script.
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

SET @FilePath = @RawDataPath + N'event_details.tsv';
SET @Sql = N'
BULK INSERT stg.EventDetails
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ''\t'',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK,
    KEEPNULLS
);';
EXEC sys.sp_executesql @Sql;

SET @FilePath = @RawDataPath + N'fighter_details.tsv';
SET @Sql = N'
BULK INSERT stg.FighterDetails
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ''\t'',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK,
    KEEPNULLS
);';
EXEC sys.sp_executesql @Sql;

SET @FilePath = @RawDataPath + N'fight_details.tsv';
SET @Sql = N'
BULK INSERT stg.FightDetails
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ''\t'',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK,
    KEEPNULLS
);';
EXEC sys.sp_executesql @Sql;

SET @FilePath = @RawDataPath + N'UFC.tsv';
SET @Sql = N'
BULK INSERT stg.UFCMaster
FROM ''' + REPLACE(@FilePath, '''', '''''') + N'''
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ''\t'',
    ROWTERMINATOR = ''0x0a'',
    CODEPAGE = ''65001'',
    TABLOCK,
    KEEPNULLS
);';
EXEC sys.sp_executesql @Sql;

SELECT 'stg.EventDetails' AS table_name, COUNT(*) AS row_count FROM stg.EventDetails
UNION ALL SELECT 'stg.FighterDetails', COUNT(*) FROM stg.FighterDetails
UNION ALL SELECT 'stg.FightDetails', COUNT(*) FROM stg.FightDetails
UNION ALL SELECT 'stg.UFCMaster', COUNT(*) FROM stg.UFCMaster;
GO
