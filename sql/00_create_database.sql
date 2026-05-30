/*
    UFC_OPRBP - 00_create_database.sql
    Run first from SSMS. Creates the project database if it does not exist.
*/
USE master;
GO

IF DB_ID(N'UFC_OPRBP') IS NULL
BEGIN
    CREATE DATABASE UFC_OPRBP;
END;
GO

ALTER DATABASE UFC_OPRBP SET RECOVERY SIMPLE;
GO

USE UFC_OPRBP;
GO

SELECT DB_NAME() AS active_database, SYSDATETIME() AS created_or_checked_at;
GO
