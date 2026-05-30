# -*- coding: utf-8 -*-
"""Generate the SQL and Markdown artifacts for the UFC SQL Server project.

The Kaggle CSV files have many repeated red/blue fighter columns. Keeping those
column lists in Python makes the generated SQL less error-prone and easy to
refresh if the dataset changes slightly.
"""

from __future__ import annotations

from pathlib import Path
from textwrap import dedent


ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
DOCS_DIR = ROOT / "docs"


FIGHT_STAT_COLS = [
    "kd",
    "sig_str_landed",
    "sig_str_atmpted",
    "sig_str_acc",
    "total_str_landed",
    "total_str_atmpted",
    "total_str_acc",
    "td_landed",
    "td_atmpted",
    "td_acc",
    "sub_att",
    "ctrl",
    "head_landed",
    "head_atmpted",
    "head_acc",
    "body_landed",
    "body_atmpted",
    "body_acc",
    "leg_landed",
    "leg_atmpted",
    "leg_acc",
    "dist_landed",
    "dist_atmpted",
    "dist_acc",
    "clinch_landed",
    "clinch_atmpted",
    "clinch_acc",
    "ground_landed",
    "ground_atmpted",
    "ground_acc",
    "landed_head_per",
    "landed_body_per",
    "landed_leg_per",
    "landed_dist_per",
    "landed_clinch_per",
    "landed_ground_per",
]

FIGHTER_ATTR_COLS = [
    "nick_name",
    "wins",
    "losses",
    "draws",
    "height",
    "weight",
    "reach",
    "stance",
    "dob",
    "splm",
    "str_acc",
    "sapm",
    "str_def",
    "td_avg",
    "td_avg_acc",
    "td_def",
    "sub_avg",
]

EVENT_DETAILS_COLS = ["event_id", "fight_id", "date", "location", "winner", "winner_id"]
FIGHTER_DETAILS_COLS = [
    "id",
    "name",
    "nick_name",
    "wins",
    "losses",
    "draws",
    "height",
    "weight",
    "reach",
    "stance",
    "dob",
    "splm",
    "str_acc",
    "sapm",
    "str_def",
    "td_avg",
    "td_avg_acc",
    "td_def",
    "sub_avg",
]

FIGHT_DETAILS_COLS = (
    [
        "event_name",
        "event_id",
        "fight_id",
        "r_name",
        "r_id",
        "b_name",
        "b_id",
        "division",
        "title_fight",
        "method",
        "finish_round",
        "match_time_sec",
        "total_rounds",
        "referee",
    ]
    + [f"r_{c}" for c in FIGHT_STAT_COLS]
    + [f"b_{c}" for c in FIGHT_STAT_COLS]
)

UFC_MASTER_COLS = (
    [
        "event_id",
        "event_name",
        "date",
        "location",
        "fight_id",
        "division",
        "title_fight",
        "method",
        "finish_round",
        "match_time_sec",
        "total_rounds",
        "referee",
        "r_name",
        "r_id",
    ]
    + [f"r_{c}" for c in FIGHT_STAT_COLS]
    + [f"r_{c}" for c in FIGHTER_ATTR_COLS]
    + ["b_name", "b_id"]
    + [f"b_{c}" for c in FIGHT_STAT_COLS]
    + [f"b_{c}" for c in FIGHTER_ATTR_COLS]
    + ["winner", "winner_id"]
)


def nvarchar_cols(cols: list[str]) -> str:
    return ",\n".join(f"    [{col}] NVARCHAR(4000) NULL" for col in cols)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.replace("\r\n", "\n").lstrip(), encoding="utf-8")


def sql_00_create_database() -> str:
    return """
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
    """


def sql_01_create_schema() -> str:
    return """
    /*
        UFC_OPRBP - 01_create_schema.sql
        Creates normalized schemas and domain tables.
        Re-running this script drops normalized objects, but does not drop staging tables.
    */
    USE UFC_OPRBP;
    GO
    SET NOCOUNT ON;
    GO

    IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
    IF SCHEMA_ID(N'geo') IS NULL EXEC(N'CREATE SCHEMA geo');
    IF SCHEMA_ID(N'ref') IS NULL EXEC(N'CREATE SCHEMA ref');
    IF SCHEMA_ID(N'ufc') IS NULL EXEC(N'CREATE SCHEMA ufc');
    IF SCHEMA_ID(N'audit') IS NULL EXEC(N'CREATE SCHEMA audit');
    GO

    DROP VIEW IF EXISTS ufc.v_weight_class_statistics;
    DROP VIEW IF EXISTS ufc.v_fighter_summary;
    DROP VIEW IF EXISTS ufc.v_event_results;
    GO

    DROP PROCEDURE IF EXISTS ufc.sp_import_fight_result_json;
    DROP PROCEDURE IF EXISTS ufc.sp_get_event_card_json;
    DROP PROCEDURE IF EXISTS ufc.sp_update_fight_result;
    DROP PROCEDURE IF EXISTS ufc.sp_fights_paging;
    DROP PROCEDURE IF EXISTS ufc.sp_compare_fighters;
    DROP PROCEDURE IF EXISTS ufc.sp_get_event_fights;
    GO

    DROP TRIGGER IF EXISTS ufc.trg_Fight_Audit;
    GO

    DROP TABLE IF EXISTS ufc.FightStrikeBreakdown;
    DROP TABLE IF EXISTS ufc.FightPerformanceStats;
    DROP TABLE IF EXISTS ufc.FightParticipant;
    DROP TABLE IF EXISTS ufc.Fight;
    DROP TABLE IF EXISTS ufc.FighterCareerStats;
    DROP TABLE IF EXISTS ufc.Fighter;
    DROP TABLE IF EXISTS ufc.Event;
    DROP TABLE IF EXISTS ref.Referee;
    DROP TABLE IF EXISTS ref.VictoryDetail;
    DROP TABLE IF EXISTS ref.VictoryMethod;
    DROP TABLE IF EXISTS ref.FightFormat;
    DROP TABLE IF EXISTS ref.WeightClass;
    DROP TABLE IF EXISTS ref.Stance;
    DROP TABLE IF EXISTS geo.City;
    DROP TABLE IF EXISTS geo.Region;
    DROP TABLE IF EXISTS geo.Country;
    DROP TABLE IF EXISTS audit.ChangeLog;
    GO

    CREATE TABLE audit.ChangeLog
    (
        change_log_id BIGINT IDENTITY(1,1) CONSTRAINT PK_ChangeLog PRIMARY KEY,
        schema_name SYSNAME NOT NULL,
        table_name SYSNAME NOT NULL,
        action_name VARCHAR(20) NOT NULL,
        key_value NVARCHAR(200) NULL,
        old_values NVARCHAR(MAX) NULL,
        new_values NVARCHAR(MAX) NULL,
        changed_at DATETIME2(0) NOT NULL CONSTRAINT DF_ChangeLog_changed_at DEFAULT SYSUTCDATETIME(),
        changed_by SYSNAME NOT NULL CONSTRAINT DF_ChangeLog_changed_by DEFAULT SUSER_SNAME(),
        CONSTRAINT CK_ChangeLog_old_json CHECK (old_values IS NULL OR ISJSON(old_values) = 1),
        CONSTRAINT CK_ChangeLog_new_json CHECK (new_values IS NULL OR ISJSON(new_values) = 1)
    );

    CREATE TABLE geo.Country
    (
        country_id INT IDENTITY(1,1) CONSTRAINT PK_Country PRIMARY KEY,
        country_name NVARCHAR(120) NOT NULL CONSTRAINT UQ_Country_country_name UNIQUE
    );

    CREATE TABLE geo.Region
    (
        region_id INT IDENTITY(1,1) CONSTRAINT PK_Region PRIMARY KEY,
        country_id INT NOT NULL,
        region_name NVARCHAR(120) NOT NULL,
        CONSTRAINT FK_Region_Country FOREIGN KEY (country_id) REFERENCES geo.Country(country_id),
        CONSTRAINT UQ_Region_country_name UNIQUE (country_id, region_name)
    );

    CREATE TABLE geo.City
    (
        city_id INT IDENTITY(1,1) CONSTRAINT PK_City PRIMARY KEY,
        region_id INT NOT NULL,
        city_name NVARCHAR(160) NOT NULL,
        CONSTRAINT FK_City_Region FOREIGN KEY (region_id) REFERENCES geo.Region(region_id),
        CONSTRAINT UQ_City_region_name UNIQUE (region_id, city_name)
    );

    CREATE TABLE ref.Stance
    (
        stance_id INT IDENTITY(1,1) CONSTRAINT PK_Stance PRIMARY KEY,
        stance_name NVARCHAR(80) NOT NULL CONSTRAINT UQ_Stance_name UNIQUE
    );

    CREATE TABLE ref.WeightClass
    (
        weight_class_id INT IDENTITY(1,1) CONSTRAINT PK_WeightClass PRIMARY KEY,
        division_name NVARCHAR(120) NOT NULL CONSTRAINT UQ_WeightClass_division UNIQUE,
        is_women BIT NOT NULL CONSTRAINT DF_WeightClass_is_women DEFAULT 0,
        is_interim BIT NOT NULL CONSTRAINT DF_WeightClass_is_interim DEFAULT 0,
        is_catch_weight BIT NOT NULL CONSTRAINT DF_WeightClass_is_catch_weight DEFAULT 0
    );

    CREATE TABLE ref.FightFormat
    (
        fight_format_id INT IDENTITY(1,1) CONSTRAINT PK_FightFormat PRIMARY KEY,
        scheduled_rounds TINYINT NOT NULL,
        format_name NVARCHAR(80) NOT NULL,
        CONSTRAINT UQ_FightFormat_rounds UNIQUE (scheduled_rounds),
        CONSTRAINT CK_FightFormat_rounds CHECK (scheduled_rounds BETWEEN 1 AND 5)
    );

    CREATE TABLE ref.VictoryMethod
    (
        victory_method_id INT IDENTITY(1,1) CONSTRAINT PK_VictoryMethod PRIMARY KEY,
        method_name NVARCHAR(120) NOT NULL CONSTRAINT UQ_VictoryMethod_name UNIQUE
    );

    CREATE TABLE ref.VictoryDetail
    (
        victory_detail_id INT IDENTITY(1,1) CONSTRAINT PK_VictoryDetail PRIMARY KEY,
        victory_method_id INT NOT NULL,
        detail_name NVARCHAR(160) NOT NULL,
        CONSTRAINT FK_VictoryDetail_Method FOREIGN KEY (victory_method_id) REFERENCES ref.VictoryMethod(victory_method_id),
        CONSTRAINT UQ_VictoryDetail_method_detail UNIQUE (victory_method_id, detail_name)
    );

    CREATE TABLE ref.Referee
    (
        referee_id INT IDENTITY(1,1) CONSTRAINT PK_Referee PRIMARY KEY,
        referee_name NVARCHAR(160) NOT NULL CONSTRAINT UQ_Referee_name UNIQUE
    );

    CREATE TABLE ufc.Fighter
    (
        fighter_id VARCHAR(32) CONSTRAINT PK_Fighter PRIMARY KEY,
        fighter_name NVARCHAR(200) NOT NULL,
        nick_name NVARCHAR(200) NULL,
        height_cm DECIMAL(6,2) NULL,
        weight_kg DECIMAL(6,2) NULL,
        reach_cm DECIMAL(6,2) NULL,
        stance_id INT NULL,
        date_of_birth DATE NULL,
        loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_Fighter_loaded_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Fighter_Stance FOREIGN KEY (stance_id) REFERENCES ref.Stance(stance_id),
        CONSTRAINT CK_Fighter_height CHECK (height_cm IS NULL OR height_cm BETWEEN 100 AND 230),
        CONSTRAINT CK_Fighter_weight CHECK (weight_kg IS NULL OR weight_kg BETWEEN 35 AND 180),
        CONSTRAINT CK_Fighter_reach CHECK (reach_cm IS NULL OR reach_cm BETWEEN 100 AND 240)
    );

    CREATE TABLE ufc.FighterCareerStats
    (
        fighter_id VARCHAR(32) CONSTRAINT PK_FighterCareerStats PRIMARY KEY,
        wins INT NULL,
        losses INT NULL,
        draws INT NULL,
        sig_strikes_landed_per_min DECIMAL(6,2) NULL,
        striking_accuracy_pct DECIMAL(6,2) NULL,
        sig_strikes_absorbed_per_min DECIMAL(6,2) NULL,
        striking_defense_pct DECIMAL(6,2) NULL,
        takedown_avg DECIMAL(6,2) NULL,
        takedown_accuracy_pct DECIMAL(6,2) NULL,
        takedown_defense_pct DECIMAL(6,2) NULL,
        submission_avg DECIMAL(6,2) NULL,
        CONSTRAINT FK_FighterCareerStats_Fighter FOREIGN KEY (fighter_id) REFERENCES ufc.Fighter(fighter_id),
        CONSTRAINT CK_FighterCareerStats_record CHECK
        (
            (wins IS NULL OR wins >= 0) AND
            (losses IS NULL OR losses >= 0) AND
            (draws IS NULL OR draws >= 0)
        )
    );

    CREATE TABLE ufc.Event
    (
        event_id VARCHAR(32) CONSTRAINT PK_Event PRIMARY KEY,
        event_name NVARCHAR(300) NOT NULL,
        event_date DATE NULL,
        city_id INT NULL,
        location_raw NVARCHAR(300) NULL,
        CONSTRAINT FK_Event_City FOREIGN KEY (city_id) REFERENCES geo.City(city_id)
    );

    CREATE TABLE ufc.Fight
    (
        fight_id VARCHAR(32) CONSTRAINT PK_Fight PRIMARY KEY,
        event_id VARCHAR(32) NOT NULL,
        weight_class_id INT NULL,
        fight_format_id INT NULL,
        victory_method_id INT NULL,
        victory_detail_id INT NULL,
        referee_id INT NULL,
        is_title_fight BIT NOT NULL CONSTRAINT DF_Fight_is_title_fight DEFAULT 0,
        finish_round TINYINT NULL,
        match_time_sec INT NULL,
        total_rounds TINYINT NULL,
        winner_fighter_id VARCHAR(32) NULL,
        is_draw_or_no_contest BIT NOT NULL CONSTRAINT DF_Fight_is_draw_or_no_contest DEFAULT 0,
        loaded_at DATETIME2(0) NOT NULL CONSTRAINT DF_Fight_loaded_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Fight_Event FOREIGN KEY (event_id) REFERENCES ufc.Event(event_id),
        CONSTRAINT FK_Fight_WeightClass FOREIGN KEY (weight_class_id) REFERENCES ref.WeightClass(weight_class_id),
        CONSTRAINT FK_Fight_FightFormat FOREIGN KEY (fight_format_id) REFERENCES ref.FightFormat(fight_format_id),
        CONSTRAINT FK_Fight_VictoryMethod FOREIGN KEY (victory_method_id) REFERENCES ref.VictoryMethod(victory_method_id),
        CONSTRAINT FK_Fight_VictoryDetail FOREIGN KEY (victory_detail_id) REFERENCES ref.VictoryDetail(victory_detail_id),
        CONSTRAINT FK_Fight_Referee FOREIGN KEY (referee_id) REFERENCES ref.Referee(referee_id),
        CONSTRAINT FK_Fight_Winner FOREIGN KEY (winner_fighter_id) REFERENCES ufc.Fighter(fighter_id),
        CONSTRAINT CK_Fight_finish_round CHECK (finish_round IS NULL OR finish_round BETWEEN 1 AND 5),
        CONSTRAINT CK_Fight_match_time CHECK (match_time_sec IS NULL OR match_time_sec BETWEEN 0 AND 1800),
        CONSTRAINT CK_Fight_total_rounds CHECK (total_rounds IS NULL OR total_rounds BETWEEN 1 AND 5)
    );

    CREATE TABLE ufc.FightParticipant
    (
        fight_id VARCHAR(32) NOT NULL,
        corner_color VARCHAR(8) NOT NULL,
        fighter_id VARCHAR(32) NOT NULL,
        is_winner BIT NOT NULL CONSTRAINT DF_FightParticipant_is_winner DEFAULT 0,
        result_label NVARCHAR(40) NOT NULL,
        CONSTRAINT PK_FightParticipant PRIMARY KEY (fight_id, corner_color),
        CONSTRAINT FK_FightParticipant_Fight FOREIGN KEY (fight_id) REFERENCES ufc.Fight(fight_id),
        CONSTRAINT FK_FightParticipant_Fighter FOREIGN KEY (fighter_id) REFERENCES ufc.Fighter(fighter_id),
        CONSTRAINT UQ_FightParticipant_fighter UNIQUE (fight_id, fighter_id),
        CONSTRAINT CK_FightParticipant_corner CHECK (corner_color IN ('Red', 'Blue'))
    );

    CREATE TABLE ufc.FightPerformanceStats
    (
        fight_id VARCHAR(32) NOT NULL,
        corner_color VARCHAR(8) NOT NULL,
        knockdowns INT NULL,
        significant_strikes_landed INT NULL,
        significant_strikes_attempted INT NULL,
        significant_strikes_accuracy_pct DECIMAL(6,2) NULL,
        total_strikes_landed INT NULL,
        total_strikes_attempted INT NULL,
        total_strikes_accuracy_pct DECIMAL(6,2) NULL,
        takedowns_landed INT NULL,
        takedowns_attempted INT NULL,
        takedown_accuracy_pct DECIMAL(6,2) NULL,
        submission_attempts INT NULL,
        control_seconds INT NULL,
        CONSTRAINT PK_FightPerformanceStats PRIMARY KEY (fight_id, corner_color),
        CONSTRAINT FK_FightPerformanceStats_Participant FOREIGN KEY (fight_id, corner_color)
            REFERENCES ufc.FightParticipant(fight_id, corner_color),
        CONSTRAINT CK_FightPerformance_sig CHECK (significant_strikes_landed IS NULL OR significant_strikes_attempted IS NULL OR significant_strikes_landed <= significant_strikes_attempted),
        CONSTRAINT CK_FightPerformance_total CHECK (total_strikes_landed IS NULL OR total_strikes_attempted IS NULL OR total_strikes_landed <= total_strikes_attempted),
        CONSTRAINT CK_FightPerformance_td CHECK (takedowns_landed IS NULL OR takedowns_attempted IS NULL OR takedowns_landed <= takedowns_attempted)
    );

    CREATE TABLE ufc.FightStrikeBreakdown
    (
        fight_id VARCHAR(32) NOT NULL,
        corner_color VARCHAR(8) NOT NULL,
        head_landed INT NULL,
        head_attempted INT NULL,
        head_accuracy_pct DECIMAL(6,2) NULL,
        body_landed INT NULL,
        body_attempted INT NULL,
        body_accuracy_pct DECIMAL(6,2) NULL,
        leg_landed INT NULL,
        leg_attempted INT NULL,
        leg_accuracy_pct DECIMAL(6,2) NULL,
        distance_landed INT NULL,
        distance_attempted INT NULL,
        distance_accuracy_pct DECIMAL(6,2) NULL,
        clinch_landed INT NULL,
        clinch_attempted INT NULL,
        clinch_accuracy_pct DECIMAL(6,2) NULL,
        ground_landed INT NULL,
        ground_attempted INT NULL,
        ground_accuracy_pct DECIMAL(6,2) NULL,
        landed_head_pct DECIMAL(6,2) NULL,
        landed_body_pct DECIMAL(6,2) NULL,
        landed_leg_pct DECIMAL(6,2) NULL,
        landed_distance_pct DECIMAL(6,2) NULL,
        landed_clinch_pct DECIMAL(6,2) NULL,
        landed_ground_pct DECIMAL(6,2) NULL,
        CONSTRAINT PK_FightStrikeBreakdown PRIMARY KEY (fight_id, corner_color),
        CONSTRAINT FK_FightStrikeBreakdown_Participant FOREIGN KEY (fight_id, corner_color)
            REFERENCES ufc.FightParticipant(fight_id, corner_color),
        CONSTRAINT CK_FightStrike_head CHECK (head_landed IS NULL OR head_attempted IS NULL OR head_landed <= head_attempted),
        CONSTRAINT CK_FightStrike_body CHECK (body_landed IS NULL OR body_attempted IS NULL OR body_landed <= body_attempted),
        CONSTRAINT CK_FightStrike_leg CHECK (leg_landed IS NULL OR leg_attempted IS NULL OR leg_landed <= leg_attempted),
        CONSTRAINT CK_FightStrike_distance CHECK (distance_landed IS NULL OR distance_attempted IS NULL OR distance_landed <= distance_attempted),
        CONSTRAINT CK_FightStrike_clinch CHECK (clinch_landed IS NULL OR clinch_attempted IS NULL OR clinch_landed <= clinch_attempted),
        CONSTRAINT CK_FightStrike_ground CHECK (ground_landed IS NULL OR ground_attempted IS NULL OR ground_landed <= ground_attempted)
    );
    GO

    PRINT 'Normalized UFC schema created.';
    GO
    """


def sql_02_create_staging() -> str:
    return f"""
    /*
        UFC_OPRBP - 02_create_staging.sql
        Creates staging tables matching the four Kaggle CSV files.
        All columns are NVARCHAR on purpose: conversion and validation happen in 04_transform_to_model.sql.
    */
    USE UFC_OPRBP;
    GO
    SET NOCOUNT ON;
    GO

    DROP TABLE IF EXISTS stg.EventDetails;
    DROP TABLE IF EXISTS stg.FightDetails;
    DROP TABLE IF EXISTS stg.FighterDetails;
    DROP TABLE IF EXISTS stg.UFCMaster;
    GO

    CREATE TABLE stg.EventDetails
    (
{nvarchar_cols(EVENT_DETAILS_COLS)}
    );

    CREATE TABLE stg.FighterDetails
    (
{nvarchar_cols(FIGHTER_DETAILS_COLS)}
    );

    CREATE TABLE stg.FightDetails
    (
{nvarchar_cols(FIGHT_DETAILS_COLS)}
    );

    CREATE TABLE stg.UFCMaster
    (
{nvarchar_cols(UFC_MASTER_COLS)}
    );
    GO

    PRINT 'Staging tables created.';
    GO
    """


def bulk_block(table: str, file_name: str) -> str:
    return f"""
    SET @FilePath = @RawDataPath + N'{file_name}';
    SET @Sql = N'
    BULK INSERT {table}
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
    PRINT '{file_name} imported into {table}';
    """


def sql_03_load() -> str:
    raw_path = str((ROOT / "data" / "raw").resolve()) + "\\"
    raw_path_sql = raw_path.replace("'", "''")
    return f"""
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

    DECLARE @RawDataPath NVARCHAR(4000) = N'{raw_path_sql}';
    DECLARE @FilePath NVARCHAR(4000);
    DECLARE @Sql NVARCHAR(MAX);

    TRUNCATE TABLE stg.EventDetails;
    TRUNCATE TABLE stg.FightDetails;
    TRUNCATE TABLE stg.FighterDetails;
    TRUNCATE TABLE stg.UFCMaster;

{bulk_block("stg.EventDetails", "event_details.csv")}
{bulk_block("stg.FighterDetails", "fighter_details.csv")}
{bulk_block("stg.FightDetails", "fight_details.csv")}
{bulk_block("stg.UFCMaster", "UFC.csv")}

    SELECT 'stg.EventDetails' AS table_name, COUNT(*) AS row_count FROM stg.EventDetails
    UNION ALL SELECT 'stg.FighterDetails', COUNT(*) FROM stg.FighterDetails
    UNION ALL SELECT 'stg.FightDetails', COUNT(*) FROM stg.FightDetails
    UNION ALL SELECT 'stg.UFCMaster', COUNT(*) FROM stg.UFCMaster;
    GO
    """


def num_expr(col: str) -> str:
    return f"CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.{col}, N'')))"


def dec_expr(col: str) -> str:
    return f"TRY_CONVERT(DECIMAL(6,2), NULLIF(v.{col}, N''))"


def perf_values() -> str:
    cols = [
        "kd",
        "sig_str_landed",
        "sig_str_atmpted",
        "sig_str_acc",
        "total_str_landed",
        "total_str_atmpted",
        "total_str_acc",
        "td_landed",
        "td_atmpted",
        "td_acc",
        "sub_att",
        "ctrl",
    ]
    red = ", ".join(["N'Red'"] + [f"m.r_{c}" for c in cols])
    blue = ", ".join(["N'Blue'"] + [f"m.b_{c}" for c in cols])
    aliases = ", ".join(["corner_color"] + cols)
    return f"(VALUES\n        ({red}),\n        ({blue})\n    ) v({aliases})"


def strike_values() -> str:
    cols = [
        "head_landed",
        "head_atmpted",
        "head_acc",
        "body_landed",
        "body_atmpted",
        "body_acc",
        "leg_landed",
        "leg_atmpted",
        "leg_acc",
        "dist_landed",
        "dist_atmpted",
        "dist_acc",
        "clinch_landed",
        "clinch_atmpted",
        "clinch_acc",
        "ground_landed",
        "ground_atmpted",
        "ground_acc",
        "landed_head_per",
        "landed_body_per",
        "landed_leg_per",
        "landed_dist_per",
        "landed_clinch_per",
        "landed_ground_per",
    ]
    red = ", ".join(["N'Red'"] + [f"m.r_{c}" for c in cols])
    blue = ", ".join(["N'Blue'"] + [f"m.b_{c}" for c in cols])
    aliases = ", ".join(["corner_color"] + cols)
    return f"(VALUES\n        ({red}),\n        ({blue})\n    ) v({aliases})"


def sql_04_transform() -> str:
    return f"""
    /*
        UFC_OPRBP - 04_transform_to_model.sql
        Transforms raw Kaggle staging data into a normalized relational model.
    */
    USE UFC_OPRBP;
    GO
    SET NOCOUNT ON;
    GO

    DELETE FROM ufc.FightStrikeBreakdown;
    DELETE FROM ufc.FightPerformanceStats;
    DELETE FROM ufc.FightParticipant;
    DELETE FROM ufc.Fight;
    DELETE FROM ufc.FighterCareerStats;
    DELETE FROM ufc.Fighter;
    DELETE FROM ufc.Event;
    DELETE FROM ref.Referee;
    DELETE FROM ref.VictoryDetail;
    DELETE FROM ref.VictoryMethod;
    DELETE FROM ref.FightFormat;
    DELETE FROM ref.WeightClass;
    DELETE FROM ref.Stance;
    DELETE FROM geo.City;
    DELETE FROM geo.Region;
    DELETE FROM geo.Country;
    DELETE FROM audit.ChangeLog;
    GO

    IF OBJECT_ID('tempdb..#ParsedLocations') IS NOT NULL DROP TABLE #ParsedLocations;

    WITH raw_locations AS
    (
        SELECT DISTINCT location_raw = NULLIF(LTRIM(RTRIM(location)), N'')
        FROM stg.UFCMaster
        WHERE NULLIF(LTRIM(RTRIM(location)), N'') IS NOT NULL
    ),
    positions AS
    (
        SELECT
            location_raw,
            first_comma = CHARINDEX(N',', location_raw),
            last_comma = LEN(location_raw) - CHARINDEX(N',', REVERSE(location_raw)) + 1
        FROM raw_locations
    )
    SELECT DISTINCT
        location_raw,
        city_name = CASE
            WHEN first_comma > 0 THEN LTRIM(RTRIM(LEFT(location_raw, first_comma - 1)))
            ELSE location_raw
        END,
        region_name = CASE
            WHEN first_comma > 0 AND first_comma <> last_comma
                THEN LTRIM(RTRIM(SUBSTRING(location_raw, first_comma + 1, last_comma - first_comma - 1)))
            ELSE N'N/A'
        END,
        country_name = CASE
            WHEN first_comma > 0 THEN LTRIM(RTRIM(SUBSTRING(location_raw, last_comma + 1, 4000)))
            ELSE N'Unknown'
        END
    INTO #ParsedLocations
    FROM positions;

    INSERT INTO geo.Country (country_name)
    SELECT DISTINCT country_name
    FROM #ParsedLocations
    WHERE country_name IS NOT NULL;

    INSERT INTO geo.Region (country_id, region_name)
    SELECT DISTINCT c.country_id, p.region_name
    FROM #ParsedLocations p
    INNER JOIN geo.Country c ON c.country_name = p.country_name;

    INSERT INTO geo.City (region_id, city_name)
    SELECT DISTINCT r.region_id, p.city_name
    FROM #ParsedLocations p
    INNER JOIN geo.Country c ON c.country_name = p.country_name
    INNER JOIN geo.Region r ON r.country_id = c.country_id AND r.region_name = p.region_name;

    WITH raw_fighters AS
    (
        SELECT id AS fighter_id, name AS fighter_name, nick_name, wins, losses, draws, height, weight, reach, stance, dob,
               splm, str_acc, sapm, str_def, td_avg, td_avg_acc, td_def, sub_avg
        FROM stg.FighterDetails
        WHERE NULLIF(id, N'') IS NOT NULL
        UNION ALL
        SELECT r_id, r_name, r_nick_name, r_wins, r_losses, r_draws, r_height, r_weight, r_reach, r_stance, r_dob,
               r_splm, r_str_acc, r_sapm, r_str_def, r_td_avg, r_td_avg_acc, r_td_def, r_sub_avg
        FROM stg.UFCMaster
        WHERE NULLIF(r_id, N'') IS NOT NULL
        UNION ALL
        SELECT b_id, b_name, b_nick_name, b_wins, b_losses, b_draws, b_height, b_weight, b_reach, b_stance, b_dob,
               b_splm, b_str_acc, b_sapm, b_str_def, b_td_avg, b_td_avg_acc, b_td_def, b_sub_avg
        FROM stg.UFCMaster
        WHERE NULLIF(b_id, N'') IS NOT NULL
    )
    INSERT INTO ref.Stance (stance_name)
    SELECT DISTINCT LTRIM(RTRIM(stance))
    FROM raw_fighters
    WHERE NULLIF(LTRIM(RTRIM(stance)), N'') IS NOT NULL;

    WITH raw_fighters AS
    (
        SELECT id AS fighter_id, name AS fighter_name, nick_name, wins, losses, draws, height, weight, reach, stance, dob,
               splm, str_acc, sapm, str_def, td_avg, td_avg_acc, td_def, sub_avg
        FROM stg.FighterDetails
        WHERE NULLIF(id, N'') IS NOT NULL
        UNION ALL
        SELECT r_id, r_name, r_nick_name, r_wins, r_losses, r_draws, r_height, r_weight, r_reach, r_stance, r_dob,
               r_splm, r_str_acc, r_sapm, r_str_def, r_td_avg, r_td_avg_acc, r_td_def, r_sub_avg
        FROM stg.UFCMaster
        WHERE NULLIF(r_id, N'') IS NOT NULL
        UNION ALL
        SELECT b_id, b_name, b_nick_name, b_wins, b_losses, b_draws, b_height, b_weight, b_reach, b_stance, b_dob,
               b_splm, b_str_acc, b_sapm, b_str_def, b_td_avg, b_td_avg_acc, b_td_def, b_sub_avg
        FROM stg.UFCMaster
        WHERE NULLIF(b_id, N'') IS NOT NULL
    ),
    grouped AS
    (
        SELECT
            fighter_id = LTRIM(RTRIM(fighter_id)),
            fighter_name = MAX(NULLIF(LTRIM(RTRIM(fighter_name)), N'')),
            nick_name = MAX(NULLIF(LTRIM(RTRIM(nick_name)), N'')),
            height_cm = MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(height, N''))),
            weight_kg = MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(weight, N''))),
            reach_cm = MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(reach, N''))),
            stance_name = MAX(NULLIF(LTRIM(RTRIM(stance)), N'')),
            date_of_birth = MAX(COALESCE(TRY_CONVERT(DATE, NULLIF(dob, N''), 111), TRY_CONVERT(DATE, NULLIF(dob, N''), 107)))
        FROM raw_fighters
        GROUP BY LTRIM(RTRIM(fighter_id))
    )
    INSERT INTO ufc.Fighter (fighter_id, fighter_name, nick_name, height_cm, weight_kg, reach_cm, stance_id, date_of_birth)
    SELECT g.fighter_id, COALESCE(g.fighter_name, N'Unknown fighter'), g.nick_name,
           g.height_cm, g.weight_kg, g.reach_cm, s.stance_id, g.date_of_birth
    FROM grouped g
    LEFT JOIN ref.Stance s ON s.stance_name = g.stance_name;

    WITH raw_fighters AS
    (
        SELECT id AS fighter_id, wins, losses, draws, splm, str_acc, sapm, str_def, td_avg, td_avg_acc, td_def, sub_avg
        FROM stg.FighterDetails
        WHERE NULLIF(id, N'') IS NOT NULL
        UNION ALL
        SELECT r_id, r_wins, r_losses, r_draws, r_splm, r_str_acc, r_sapm, r_str_def, r_td_avg, r_td_avg_acc, r_td_def, r_sub_avg
        FROM stg.UFCMaster
        WHERE NULLIF(r_id, N'') IS NOT NULL
        UNION ALL
        SELECT b_id, b_wins, b_losses, b_draws, b_splm, b_str_acc, b_sapm, b_str_def, b_td_avg, b_td_avg_acc, b_td_def, b_sub_avg
        FROM stg.UFCMaster
        WHERE NULLIF(b_id, N'') IS NOT NULL
    )
    INSERT INTO ufc.FighterCareerStats
    (
        fighter_id, wins, losses, draws, sig_strikes_landed_per_min, striking_accuracy_pct,
        sig_strikes_absorbed_per_min, striking_defense_pct, takedown_avg, takedown_accuracy_pct,
        takedown_defense_pct, submission_avg
    )
    SELECT
        fighter_id,
        MAX(TRY_CONVERT(INT, NULLIF(wins, N''))),
        MAX(TRY_CONVERT(INT, NULLIF(losses, N''))),
        MAX(TRY_CONVERT(INT, NULLIF(draws, N''))),
        MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(splm, N''))),
        MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(str_acc, N''))),
        MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(sapm, N''))),
        MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(str_def, N''))),
        MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(td_avg, N''))),
        MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(td_avg_acc, N''))),
        MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(td_def, N''))),
        MAX(TRY_CONVERT(DECIMAL(6,2), NULLIF(sub_avg, N'')))
    FROM raw_fighters
    GROUP BY fighter_id;

    INSERT INTO ref.WeightClass (division_name, is_women, is_interim, is_catch_weight)
    SELECT DISTINCT
        LTRIM(RTRIM(division)),
        CASE WHEN LOWER(division) LIKE N'women%' THEN 1 ELSE 0 END,
        CASE WHEN LOWER(division) LIKE N'interim%' THEN 1 ELSE 0 END,
        CASE WHEN LOWER(division) LIKE N'%catch%' THEN 1 ELSE 0 END
    FROM stg.UFCMaster
    WHERE NULLIF(LTRIM(RTRIM(division)), N'') IS NOT NULL;

    INSERT INTO ref.FightFormat (scheduled_rounds, format_name)
    SELECT DISTINCT
        CONVERT(TINYINT, TRY_CONVERT(DECIMAL(5,2), NULLIF(total_rounds, N''))),
        CONCAT(CONVERT(TINYINT, TRY_CONVERT(DECIMAL(5,2), NULLIF(total_rounds, N''))), N'-round fight')
    FROM stg.UFCMaster
    WHERE TRY_CONVERT(DECIMAL(5,2), NULLIF(total_rounds, N'')) IS NOT NULL;

    WITH methods AS
    (
        SELECT DISTINCT
            method_raw = LTRIM(RTRIM(method)),
            method_name = CASE WHEN CHARINDEX(N' - ', method) > 0
                THEN LTRIM(RTRIM(LEFT(method, CHARINDEX(N' - ', method) - 1)))
                ELSE LTRIM(RTRIM(method)) END,
            detail_name = CASE WHEN CHARINDEX(N' - ', method) > 0
                THEN LTRIM(RTRIM(SUBSTRING(method, CHARINDEX(N' - ', method) + 3, 4000)))
                ELSE N'Standard' END
        FROM stg.UFCMaster
        WHERE NULLIF(LTRIM(RTRIM(method)), N'') IS NOT NULL
    )
    INSERT INTO ref.VictoryMethod (method_name)
    SELECT DISTINCT method_name
    FROM methods;

    WITH methods AS
    (
        SELECT DISTINCT
            method_name = CASE WHEN CHARINDEX(N' - ', method) > 0
                THEN LTRIM(RTRIM(LEFT(method, CHARINDEX(N' - ', method) - 1)))
                ELSE LTRIM(RTRIM(method)) END,
            detail_name = CASE WHEN CHARINDEX(N' - ', method) > 0
                THEN LTRIM(RTRIM(SUBSTRING(method, CHARINDEX(N' - ', method) + 3, 4000)))
                ELSE N'Standard' END
        FROM stg.UFCMaster
        WHERE NULLIF(LTRIM(RTRIM(method)), N'') IS NOT NULL
    )
    INSERT INTO ref.VictoryDetail (victory_method_id, detail_name)
    SELECT DISTINCT vm.victory_method_id, m.detail_name
    FROM methods m
    INNER JOIN ref.VictoryMethod vm ON vm.method_name = m.method_name;

    INSERT INTO ref.Referee (referee_name)
    SELECT DISTINCT LTRIM(RTRIM(referee))
    FROM stg.UFCMaster
    WHERE NULLIF(LTRIM(RTRIM(referee)), N'') IS NOT NULL;

    INSERT INTO ufc.Event (event_id, event_name, event_date, city_id, location_raw)
    SELECT
        m.event_id,
        MAX(NULLIF(LTRIM(RTRIM(m.event_name)), N'')),
        MIN(TRY_CONVERT(DATE, NULLIF(m.date, N''), 111)),
        MAX(c.city_id),
        MAX(NULLIF(LTRIM(RTRIM(m.location)), N''))
    FROM stg.UFCMaster m
    LEFT JOIN #ParsedLocations p ON p.location_raw = m.location
    LEFT JOIN geo.Country co ON co.country_name = p.country_name
    LEFT JOIN geo.Region r ON r.country_id = co.country_id AND r.region_name = p.region_name
    LEFT JOIN geo.City c ON c.region_id = r.region_id AND c.city_name = p.city_name
    WHERE NULLIF(m.event_id, N'') IS NOT NULL
    GROUP BY m.event_id;

    WITH fight_source AS
    (
        SELECT
            m.*,
            method_name = CASE WHEN CHARINDEX(N' - ', m.method) > 0
                THEN LTRIM(RTRIM(LEFT(m.method, CHARINDEX(N' - ', m.method) - 1)))
                ELSE LTRIM(RTRIM(m.method)) END,
            detail_name = CASE WHEN CHARINDEX(N' - ', m.method) > 0
                THEN LTRIM(RTRIM(SUBSTRING(m.method, CHARINDEX(N' - ', m.method) + 3, 4000)))
                ELSE N'Standard' END
        FROM stg.UFCMaster m
        WHERE NULLIF(m.fight_id, N'') IS NOT NULL
    )
    INSERT INTO ufc.Fight
    (
        fight_id, event_id, weight_class_id, fight_format_id, victory_method_id, victory_detail_id,
        referee_id, is_title_fight, finish_round, match_time_sec, total_rounds, winner_fighter_id,
        is_draw_or_no_contest
    )
    SELECT
        fs.fight_id,
        fs.event_id,
        wc.weight_class_id,
        ff.fight_format_id,
        vm.victory_method_id,
        vd.victory_detail_id,
        rr.referee_id,
        CASE WHEN TRY_CONVERT(INT, NULLIF(fs.title_fight, N'')) = 1 THEN 1 ELSE 0 END,
        CONVERT(TINYINT, TRY_CONVERT(DECIMAL(5,2), NULLIF(fs.finish_round, N''))),
        CONVERT(INT, TRY_CONVERT(DECIMAL(10,2), NULLIF(fs.match_time_sec, N''))),
        CONVERT(TINYINT, TRY_CONVERT(DECIMAL(5,2), NULLIF(fs.total_rounds, N''))),
        NULLIF(fs.winner_id, N''),
        CASE WHEN NULLIF(fs.winner_id, N'') IS NULL THEN 1 ELSE 0 END
    FROM fight_source fs
    LEFT JOIN ref.WeightClass wc ON wc.division_name = LTRIM(RTRIM(fs.division))
    LEFT JOIN ref.FightFormat ff ON ff.scheduled_rounds = CONVERT(TINYINT, TRY_CONVERT(DECIMAL(5,2), NULLIF(fs.total_rounds, N'')))
    LEFT JOIN ref.VictoryMethod vm ON vm.method_name = fs.method_name
    LEFT JOIN ref.VictoryDetail vd ON vd.victory_method_id = vm.victory_method_id AND vd.detail_name = fs.detail_name
    LEFT JOIN ref.Referee rr ON rr.referee_name = LTRIM(RTRIM(fs.referee));

    INSERT INTO ufc.FightParticipant (fight_id, corner_color, fighter_id, is_winner, result_label)
    SELECT
        m.fight_id,
        v.corner_color,
        v.fighter_id,
        CASE WHEN v.fighter_id = NULLIF(m.winner_id, N'') THEN 1 ELSE 0 END,
        CASE
            WHEN NULLIF(m.winner_id, N'') IS NULL THEN N'Draw/NC'
            WHEN v.fighter_id = NULLIF(m.winner_id, N'') THEN N'Win'
            ELSE N'Loss'
        END
    FROM stg.UFCMaster m
    CROSS APPLY (VALUES
        ('Red', NULLIF(m.r_id, N'')),
        ('Blue', NULLIF(m.b_id, N''))
    ) v(corner_color, fighter_id)
    WHERE NULLIF(m.fight_id, N'') IS NOT NULL
      AND v.fighter_id IS NOT NULL;

    INSERT INTO ufc.FightPerformanceStats
    (
        fight_id, corner_color, knockdowns, significant_strikes_landed, significant_strikes_attempted,
        significant_strikes_accuracy_pct, total_strikes_landed, total_strikes_attempted,
        total_strikes_accuracy_pct, takedowns_landed, takedowns_attempted, takedown_accuracy_pct,
        submission_attempts, control_seconds
    )
    SELECT
        m.fight_id,
        v.corner_color,
        {num_expr("kd")},
        {num_expr("sig_str_landed")},
        {num_expr("sig_str_atmpted")},
        {dec_expr("sig_str_acc")},
        {num_expr("total_str_landed")},
        {num_expr("total_str_atmpted")},
        {dec_expr("total_str_acc")},
        {num_expr("td_landed")},
        {num_expr("td_atmpted")},
        {dec_expr("td_acc")},
        {num_expr("sub_att")},
        {num_expr("ctrl")}
    FROM stg.UFCMaster m
    CROSS APPLY {perf_values()}
    WHERE NULLIF(m.fight_id, N'') IS NOT NULL;

    INSERT INTO ufc.FightStrikeBreakdown
    (
        fight_id, corner_color, head_landed, head_attempted, head_accuracy_pct,
        body_landed, body_attempted, body_accuracy_pct, leg_landed, leg_attempted, leg_accuracy_pct,
        distance_landed, distance_attempted, distance_accuracy_pct, clinch_landed, clinch_attempted,
        clinch_accuracy_pct, ground_landed, ground_attempted, ground_accuracy_pct,
        landed_head_pct, landed_body_pct, landed_leg_pct, landed_distance_pct, landed_clinch_pct,
        landed_ground_pct
    )
    SELECT
        m.fight_id,
        v.corner_color,
        {num_expr("head_landed")},
        {num_expr("head_atmpted")},
        {dec_expr("head_acc")},
        {num_expr("body_landed")},
        {num_expr("body_atmpted")},
        {dec_expr("body_acc")},
        {num_expr("leg_landed")},
        {num_expr("leg_atmpted")},
        {dec_expr("leg_acc")},
        {num_expr("dist_landed")},
        {num_expr("dist_atmpted")},
        {dec_expr("dist_acc")},
        {num_expr("clinch_landed")},
        {num_expr("clinch_atmpted")},
        {dec_expr("clinch_acc")},
        {num_expr("ground_landed")},
        {num_expr("ground_atmpted")},
        {dec_expr("ground_acc")},
        {dec_expr("landed_head_per")},
        {dec_expr("landed_body_per")},
        {dec_expr("landed_leg_per")},
        {dec_expr("landed_dist_per")},
        {dec_expr("landed_clinch_per")},
        {dec_expr("landed_ground_per")}
    FROM stg.UFCMaster m
    CROSS APPLY {strike_values()}
    WHERE NULLIF(m.fight_id, N'') IS NOT NULL;

    SELECT 'geo.Country' AS table_name, COUNT(*) AS row_count FROM geo.Country
    UNION ALL SELECT 'geo.Region', COUNT(*) FROM geo.Region
    UNION ALL SELECT 'geo.City', COUNT(*) FROM geo.City
    UNION ALL SELECT 'ufc.Event', COUNT(*) FROM ufc.Event
    UNION ALL SELECT 'ufc.Fighter', COUNT(*) FROM ufc.Fighter
    UNION ALL SELECT 'ufc.Fight', COUNT(*) FROM ufc.Fight
    UNION ALL SELECT 'ufc.FightParticipant', COUNT(*) FROM ufc.FightParticipant
    UNION ALL SELECT 'ufc.FightPerformanceStats', COUNT(*) FROM ufc.FightPerformanceStats
    UNION ALL SELECT 'ufc.FightStrikeBreakdown', COUNT(*) FROM ufc.FightStrikeBreakdown;
    GO
    """


def sql_05_views_triggers() -> str:
    return """
    /*
        UFC_OPRBP - 05_views_triggers_transactions.sql
        Creates reporting views and an audit trigger. The transaction demo at the end
        can be executed safely because it rolls back.
    */
    USE UFC_OPRBP;
    GO

    DROP VIEW IF EXISTS ufc.v_weight_class_statistics;
    DROP VIEW IF EXISTS ufc.v_fighter_summary;
    DROP VIEW IF EXISTS ufc.v_event_results;
    GO

    CREATE VIEW ufc.v_event_results
    AS
    SELECT
        e.event_id,
        e.event_name,
        e.event_date,
        e.location_raw,
        city = c.city_name,
        region = r.region_name,
        country = co.country_name,
        f.fight_id,
        wc.division_name,
        f.is_title_fight,
        scheduled_rounds = f.total_rounds,
        f.finish_round,
        f.match_time_sec,
        method = vm.method_name,
        method_detail = vd.detail_name,
        referee = rr.referee_name,
        red_fighter = red_f.fighter_name,
        blue_fighter = blue_f.fighter_name,
        winner = win_f.fighter_name,
        f.is_draw_or_no_contest
    FROM ufc.Fight f
    INNER JOIN ufc.Event e ON e.event_id = f.event_id
    LEFT JOIN geo.City c ON c.city_id = e.city_id
    LEFT JOIN geo.Region r ON r.region_id = c.region_id
    LEFT JOIN geo.Country co ON co.country_id = r.country_id
    LEFT JOIN ref.WeightClass wc ON wc.weight_class_id = f.weight_class_id
    LEFT JOIN ref.VictoryMethod vm ON vm.victory_method_id = f.victory_method_id
    LEFT JOIN ref.VictoryDetail vd ON vd.victory_detail_id = f.victory_detail_id
    LEFT JOIN ref.Referee rr ON rr.referee_id = f.referee_id
    LEFT JOIN ufc.FightParticipant red ON red.fight_id = f.fight_id AND red.corner_color = 'Red'
    LEFT JOIN ufc.Fighter red_f ON red_f.fighter_id = red.fighter_id
    LEFT JOIN ufc.FightParticipant blue ON blue.fight_id = f.fight_id AND blue.corner_color = 'Blue'
    LEFT JOIN ufc.Fighter blue_f ON blue_f.fighter_id = blue.fighter_id
    LEFT JOIN ufc.Fighter win_f ON win_f.fighter_id = f.winner_fighter_id;
    GO

    CREATE VIEW ufc.v_fighter_summary
    AS
    SELECT
        fi.fighter_id,
        fi.fighter_name,
        fi.nick_name,
        stance = s.stance_name,
        fi.height_cm,
        fi.weight_kg,
        fi.reach_cm,
        fi.date_of_birth,
        cs.wins AS listed_wins,
        cs.losses AS listed_losses,
        cs.draws AS listed_draws,
        fights_in_dataset = COUNT(fp.fight_id),
        wins_in_dataset = SUM(CASE WHEN fp.result_label = N'Win' THEN 1 ELSE 0 END),
        losses_in_dataset = SUM(CASE WHEN fp.result_label = N'Loss' THEN 1 ELSE 0 END),
        draw_nc_in_dataset = SUM(CASE WHEN fp.result_label = N'Draw/NC' THEN 1 ELSE 0 END),
        title_fights = SUM(CASE WHEN f.is_title_fight = 1 THEN 1 ELSE 0 END),
        avg_sig_strikes_landed = AVG(CONVERT(DECIMAL(10,2), ps.significant_strikes_landed)),
        avg_takedowns_landed = AVG(CONVERT(DECIMAL(10,2), ps.takedowns_landed))
    FROM ufc.Fighter fi
    LEFT JOIN ref.Stance s ON s.stance_id = fi.stance_id
    LEFT JOIN ufc.FighterCareerStats cs ON cs.fighter_id = fi.fighter_id
    LEFT JOIN ufc.FightParticipant fp ON fp.fighter_id = fi.fighter_id
    LEFT JOIN ufc.Fight f ON f.fight_id = fp.fight_id
    LEFT JOIN ufc.FightPerformanceStats ps ON ps.fight_id = fp.fight_id AND ps.corner_color = fp.corner_color
    GROUP BY fi.fighter_id, fi.fighter_name, fi.nick_name, s.stance_name, fi.height_cm,
             fi.weight_kg, fi.reach_cm, fi.date_of_birth, cs.wins, cs.losses, cs.draws;
    GO

    CREATE VIEW ufc.v_weight_class_statistics
    AS
    SELECT
        wc.weight_class_id,
        wc.division_name,
        wc.is_women,
        wc.is_interim,
        wc.is_catch_weight,
        fight_count = COUNT(f.fight_id),
        title_fight_count = SUM(CASE WHEN f.is_title_fight = 1 THEN 1 ELSE 0 END),
        avg_finish_seconds = AVG(CONVERT(DECIMAL(10,2), ((ISNULL(f.finish_round, 1) - 1) * 300) + ISNULL(f.match_time_sec, 0))),
        ko_tko_count = SUM(CASE WHEN vm.method_name LIKE N'%KO%' OR vm.method_name LIKE N'%TKO%' THEN 1 ELSE 0 END),
        submission_count = SUM(CASE WHEN vm.method_name = N'Submission' THEN 1 ELSE 0 END),
        decision_count = SUM(CASE WHEN vm.method_name = N'Decision' THEN 1 ELSE 0 END)
    FROM ref.WeightClass wc
    LEFT JOIN ufc.Fight f ON f.weight_class_id = wc.weight_class_id
    LEFT JOIN ref.VictoryMethod vm ON vm.victory_method_id = f.victory_method_id
    GROUP BY wc.weight_class_id, wc.division_name, wc.is_women, wc.is_interim, wc.is_catch_weight;
    GO

    DROP TRIGGER IF EXISTS ufc.trg_Fight_Audit;
    GO

    CREATE TRIGGER ufc.trg_Fight_Audit
    ON ufc.Fight
    AFTER INSERT, UPDATE, DELETE
    AS
    BEGIN
        SET NOCOUNT ON;

        INSERT INTO audit.ChangeLog (schema_name, table_name, action_name, key_value, old_values, new_values)
        SELECT
            N'ufc',
            N'Fight',
            CASE
                WHEN i.fight_id IS NOT NULL AND d.fight_id IS NOT NULL THEN 'UPDATE'
                WHEN i.fight_id IS NOT NULL THEN 'INSERT'
                ELSE 'DELETE'
            END,
            COALESCE(i.fight_id, d.fight_id),
            CASE WHEN d.fight_id IS NULL THEN NULL ELSE
                (SELECT d.fight_id, d.event_id, d.weight_class_id, d.fight_format_id,
                        d.victory_method_id, d.victory_detail_id, d.referee_id,
                        d.is_title_fight, d.finish_round, d.match_time_sec, d.total_rounds,
                        d.winner_fighter_id, d.is_draw_or_no_contest
                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
            END,
            CASE WHEN i.fight_id IS NULL THEN NULL ELSE
                (SELECT i.fight_id, i.event_id, i.weight_class_id, i.fight_format_id,
                        i.victory_method_id, i.victory_detail_id, i.referee_id,
                        i.is_title_fight, i.finish_round, i.match_time_sec, i.total_rounds,
                        i.winner_fighter_id, i.is_draw_or_no_contest
                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
            END
        FROM inserted i
        FULL OUTER JOIN deleted d ON d.fight_id = i.fight_id;
    END;
    GO

    -- Safe transaction demo: update one row, inspect the audit trigger, then roll back.
    BEGIN TRANSACTION;
        DECLARE @DemoFightId VARCHAR(32) = (SELECT TOP (1) fight_id FROM ufc.Fight ORDER BY loaded_at DESC, fight_id);

        UPDATE ufc.Fight
        SET match_time_sec = ISNULL(match_time_sec, 0)
        WHERE fight_id = @DemoFightId;

        SELECT TOP (5) *
        FROM audit.ChangeLog
        WHERE table_name = N'Fight'
        ORDER BY change_log_id DESC;
    ROLLBACK TRANSACTION;
    GO
    """


def sql_06_procedures_json() -> str:
    return """
    /*
        UFC_OPRBP - 06_procedures_json.sql
        Stored procedures, transaction handling and JSON examples.
    */
    USE UFC_OPRBP;
    GO

    DROP PROCEDURE IF EXISTS ufc.sp_import_fight_result_json;
    DROP PROCEDURE IF EXISTS ufc.sp_get_event_card_json;
    DROP PROCEDURE IF EXISTS ufc.sp_update_fight_result;
    DROP PROCEDURE IF EXISTS ufc.sp_fights_paging;
    DROP PROCEDURE IF EXISTS ufc.sp_compare_fighters;
    DROP PROCEDURE IF EXISTS ufc.sp_get_event_fights;
    GO

    CREATE PROCEDURE ufc.sp_get_event_fights
        @event_id VARCHAR(32) = NULL,
        @event_name_search NVARCHAR(200) = NULL
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT *
        FROM ufc.v_event_results
        WHERE (@event_id IS NULL OR event_id = @event_id)
          AND (@event_name_search IS NULL OR event_name LIKE N'%' + @event_name_search + N'%')
        ORDER BY event_date DESC, is_title_fight DESC, division_name;
    END;
    GO

    CREATE PROCEDURE ufc.sp_compare_fighters
        @fighter1_id VARCHAR(32),
        @fighter2_id VARCHAR(32)
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT
            fighter_order = CASE WHEN fighter_id = @fighter1_id THEN 1 ELSE 2 END,
            fighter_id,
            fighter_name,
            nick_name,
            stance,
            height_cm,
            reach_cm,
            listed_wins,
            listed_losses,
            fights_in_dataset,
            wins_in_dataset,
            losses_in_dataset,
            avg_sig_strikes_landed,
            avg_takedowns_landed
        FROM ufc.v_fighter_summary
        WHERE fighter_id IN (@fighter1_id, @fighter2_id)
        ORDER BY fighter_order;
    END;
    GO

    CREATE PROCEDURE ufc.sp_fights_paging
        @division_name NVARCHAR(120) = NULL,
        @skip INT = 0,
        @getRows INT = 20
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT
            event_date, event_name, division_name, red_fighter, blue_fighter,
            winner, method, method_detail, finish_round, match_time_sec
        FROM ufc.v_event_results
        WHERE (@division_name IS NULL OR division_name = @division_name)
        ORDER BY event_date DESC, event_name, fight_id
        OFFSET @skip ROWS
        FETCH NEXT @getRows ROWS ONLY;
    END;
    GO

    CREATE PROCEDURE ufc.sp_update_fight_result
        @fight_id VARCHAR(32),
        @winner_fighter_id VARCHAR(32) = NULL,
        @method_name NVARCHAR(120) = NULL,
        @detail_name NVARCHAR(160) = N'Standard',
        @finish_round TINYINT = NULL,
        @match_time_sec INT = NULL,
        @commit_changes BIT = 0
    AS
    BEGIN
        SET NOCOUNT ON;
        SET XACT_ABORT ON;

        BEGIN TRY
            BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM ufc.Fight WHERE fight_id = @fight_id)
                THROW 51000, 'Fight does not exist.', 1;

            IF @winner_fighter_id IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM ufc.FightParticipant WHERE fight_id = @fight_id AND fighter_id = @winner_fighter_id)
                THROW 51001, 'Winner must be one of the fight participants.', 1;

            DECLARE @method_id INT = NULL;
            DECLARE @detail_id INT = NULL;

            IF @method_name IS NOT NULL
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM ref.VictoryMethod WHERE method_name = @method_name)
                    INSERT INTO ref.VictoryMethod (method_name) VALUES (@method_name);

                SELECT @method_id = victory_method_id
                FROM ref.VictoryMethod
                WHERE method_name = @method_name;

                IF NOT EXISTS
                (
                    SELECT 1
                    FROM ref.VictoryDetail
                    WHERE victory_method_id = @method_id
                      AND detail_name = ISNULL(@detail_name, N'Standard')
                )
                    INSERT INTO ref.VictoryDetail (victory_method_id, detail_name)
                    VALUES (@method_id, ISNULL(@detail_name, N'Standard'));

                SELECT @detail_id = victory_detail_id
                FROM ref.VictoryDetail
                WHERE victory_method_id = @method_id
                  AND detail_name = ISNULL(@detail_name, N'Standard');
            END;

            UPDATE ufc.Fight
            SET winner_fighter_id = @winner_fighter_id,
                is_draw_or_no_contest = CASE WHEN @winner_fighter_id IS NULL THEN 1 ELSE 0 END,
                victory_method_id = COALESCE(@method_id, victory_method_id),
                victory_detail_id = COALESCE(@detail_id, victory_detail_id),
                finish_round = COALESCE(@finish_round, finish_round),
                match_time_sec = COALESCE(@match_time_sec, match_time_sec)
            WHERE fight_id = @fight_id;

            UPDATE ufc.FightParticipant
            SET is_winner = CASE WHEN fighter_id = @winner_fighter_id THEN 1 ELSE 0 END,
                result_label = CASE
                    WHEN @winner_fighter_id IS NULL THEN N'Draw/NC'
                    WHEN fighter_id = @winner_fighter_id THEN N'Win'
                    ELSE N'Loss'
                END
            WHERE fight_id = @fight_id;

            SELECT 'Preview after update' AS message, *
            FROM ufc.v_event_results
            WHERE fight_id = @fight_id;

            IF @commit_changes = 1
            BEGIN
                COMMIT TRANSACTION;
                SELECT 'COMMIT completed. Trigger audit row is permanent.' AS transaction_result;
            END
            ELSE
            BEGIN
                ROLLBACK TRANSACTION;
                SELECT 'ROLLBACK completed. Data and audit row were reverted.' AS transaction_result;
            END;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END;
    GO

    CREATE PROCEDURE ufc.sp_get_event_card_json
        @event_id VARCHAR(32)
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT
            e.event_id,
            e.event_name,
            e.event_date,
            e.location_raw,
            fights =
            (
                SELECT
                    vr.fight_id,
                    vr.division_name,
                    vr.is_title_fight,
                    vr.red_fighter,
                    vr.blue_fighter,
                    vr.winner,
                    vr.method,
                    vr.method_detail,
                    vr.finish_round,
                    vr.match_time_sec,
                    participants =
                    (
                        SELECT
                            fp.corner_color,
                            fi.fighter_id,
                            fi.fighter_name,
                            fp.result_label,
                            ps.significant_strikes_landed,
                            ps.significant_strikes_attempted,
                            ps.takedowns_landed,
                            ps.submission_attempts
                        FROM ufc.FightParticipant fp
                        INNER JOIN ufc.Fighter fi ON fi.fighter_id = fp.fighter_id
                        LEFT JOIN ufc.FightPerformanceStats ps
                            ON ps.fight_id = fp.fight_id AND ps.corner_color = fp.corner_color
                        WHERE fp.fight_id = vr.fight_id
                        ORDER BY fp.corner_color DESC
                        FOR JSON PATH
                    )
                FROM ufc.v_event_results vr
                WHERE vr.event_id = e.event_id
                ORDER BY vr.is_title_fight DESC, vr.division_name
                FOR JSON PATH
            )
        FROM ufc.Event e
        WHERE e.event_id = @event_id
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
    END;
    GO

    CREATE PROCEDURE ufc.sp_import_fight_result_json
        @payload NVARCHAR(MAX),
        @commit_changes BIT = 0
    AS
    BEGIN
        SET NOCOUNT ON;

        IF ISJSON(@payload) <> 1
            THROW 52000, 'Payload must be valid JSON.', 1;

        DECLARE @fight_id VARCHAR(32) = JSON_VALUE(@payload, '$.fight_id');
        DECLARE @winner_fighter_id VARCHAR(32) = JSON_VALUE(@payload, '$.winner_fighter_id');
        DECLARE @method_name NVARCHAR(120) = JSON_VALUE(@payload, '$.method_name');
        DECLARE @detail_name NVARCHAR(160) = JSON_VALUE(@payload, '$.detail_name');
        DECLARE @finish_round TINYINT = TRY_CONVERT(TINYINT, JSON_VALUE(@payload, '$.finish_round'));
        DECLARE @match_time_sec INT = TRY_CONVERT(INT, JSON_VALUE(@payload, '$.match_time_sec'));

        EXEC ufc.sp_update_fight_result
            @fight_id = @fight_id,
            @winner_fighter_id = @winner_fighter_id,
            @method_name = @method_name,
            @detail_name = @detail_name,
            @finish_round = @finish_round,
            @match_time_sec = @match_time_sec,
            @commit_changes = @commit_changes;
    END;
    GO
    """


def sql_07_demo_queries() -> str:
    return """
    /*
        UFC_OPRBP - 07_demo_queries.sql
        Queries for screenshots and oral defense.
    */
    USE UFC_OPRBP;
    GO

    -- 1) Basic SELECT + ORDER BY
    SELECT TOP (20) event_date, event_name, location_raw
    FROM ufc.Event
    ORDER BY event_date DESC;

    -- 2) JOIN: fights with both fighters and result
    SELECT TOP (30)
        event_date, event_name, division_name, red_fighter, blue_fighter, winner, method, finish_round
    FROM ufc.v_event_results
    WHERE country = N'USA'
    ORDER BY event_date DESC;

    -- 3) GROUP BY + HAVING: weight classes with many fights
    SELECT division_name, COUNT(*) AS fight_count
    FROM ufc.v_event_results
    GROUP BY division_name
    HAVING COUNT(*) >= 100
    ORDER BY fight_count DESC;

    -- 4) INSERT, UPDATE, DELETE inside transaction so the demo leaves no permanent data.
    BEGIN TRANSACTION;
        INSERT INTO ref.Referee (referee_name) VALUES (N'Demo Referee');
        UPDATE ref.Referee SET referee_name = N'Demo Referee Updated' WHERE referee_name = N'Demo Referee';
        SELECT * FROM ref.Referee WHERE referee_name LIKE N'Demo Referee%';
        DELETE FROM ref.Referee WHERE referee_name = N'Demo Referee Updated';
    ROLLBACK TRANSACTION;

    -- 5) CTE: top finishers by non-decision wins in the dataset
    WITH fighter_finishes AS
    (
        SELECT
            fp.fighter_id,
            fi.fighter_name,
            finish_wins = COUNT(*)
        FROM ufc.FightParticipant fp
        INNER JOIN ufc.Fighter fi ON fi.fighter_id = fp.fighter_id
        INNER JOIN ufc.Fight f ON f.fight_id = fp.fight_id
        INNER JOIN ref.VictoryMethod vm ON vm.victory_method_id = f.victory_method_id
        WHERE fp.is_winner = 1
          AND vm.method_name <> N'Decision'
        GROUP BY fp.fighter_id, fi.fighter_name
    )
    SELECT TOP (15) *
    FROM fighter_finishes
    ORDER BY finish_wins DESC, fighter_name;

    -- 6) Window function: rank fighters by wins inside each weight class.
    WITH wins_by_division AS
    (
        SELECT
            division_name = wc.division_name,
            fi.fighter_name,
            wins = COUNT(*)
        FROM ufc.FightParticipant fp
        INNER JOIN ufc.Fighter fi ON fi.fighter_id = fp.fighter_id
        INNER JOIN ufc.Fight f ON f.fight_id = fp.fight_id
        INNER JOIN ref.WeightClass wc ON wc.weight_class_id = f.weight_class_id
        WHERE fp.is_winner = 1
        GROUP BY wc.division_name, fi.fighter_name
    )
    SELECT *
    FROM
    (
        SELECT
            division_name,
            fighter_name,
            wins,
            division_rank = DENSE_RANK() OVER (PARTITION BY division_name ORDER BY wins DESC)
        FROM wins_by_division
    ) ranked
    WHERE division_rank <= 5
    ORDER BY division_name, division_rank, fighter_name;

    -- 7) Subquery: events with more fights than average event size.
    SELECT e.event_name, e.event_date, COUNT(f.fight_id) AS fights_on_card
    FROM ufc.Event e
    INNER JOIN ufc.Fight f ON f.event_id = e.event_id
    GROUP BY e.event_name, e.event_date
    HAVING COUNT(f.fight_id) >
    (
        SELECT AVG(CONVERT(DECIMAL(10,2), fights_per_event))
        FROM
        (
            SELECT COUNT(*) AS fights_per_event
            FROM ufc.Fight
            GROUP BY event_id
        ) x
    )
    ORDER BY fights_on_card DESC, e.event_date DESC;

    -- 8) OFFSET/FETCH paging through recent lightweight fights.
    EXEC ufc.sp_fights_paging @division_name = N'lightweight', @skip = 0, @getRows = 10;

    -- 9) JSON export for the latest event in the dataset.
    DECLARE @LatestEventId VARCHAR(32) = (SELECT TOP (1) event_id FROM ufc.Event ORDER BY event_date DESC);
    EXEC ufc.sp_get_event_card_json @event_id = @LatestEventId;

    -- 10) JSON input + transaction rollback demo.
    DECLARE @DemoFightId VARCHAR(32) =
    (
        SELECT TOP (1) fight_id
        FROM ufc.Fight
        WHERE winner_fighter_id IS NOT NULL
        ORDER BY loaded_at DESC, fight_id
    );
    DECLARE @DemoWinnerId VARCHAR(32) =
    (
        SELECT TOP (1) fighter_id
        FROM ufc.FightParticipant
        WHERE fight_id = @DemoFightId
        ORDER BY corner_color
    );
    DECLARE @Payload NVARCHAR(MAX) =
    (
        SELECT
            @DemoFightId AS fight_id,
            @DemoWinnerId AS winner_fighter_id,
            N'Decision' AS method_name,
            N'Unanimous' AS detail_name,
            3 AS finish_round,
            300 AS match_time_sec
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    SELECT @Payload AS json_payload, ISJSON(@Payload) AS is_valid_json;
    EXEC ufc.sp_import_fight_result_json @payload = @Payload, @commit_changes = 0;

    -- 11) Acceptance checks
    SELECT 'Fights without two participants' AS check_name, COUNT(*) AS issue_count
    FROM
    (
        SELECT fight_id
        FROM ufc.FightParticipant
        GROUP BY fight_id
        HAVING COUNT(*) <> 2
    ) x
    UNION ALL
    SELECT 'Orphan fight participants', COUNT(*)
    FROM ufc.FightParticipant fp
    LEFT JOIN ufc.Fight f ON f.fight_id = fp.fight_id
    WHERE f.fight_id IS NULL
    UNION ALL
    SELECT 'Invalid strike rows', COUNT(*)
    FROM ufc.FightPerformanceStats
    WHERE significant_strikes_landed > significant_strikes_attempted
       OR total_strikes_landed > total_strikes_attempted
       OR takedowns_landed > takedowns_attempted;
    GO
    """


def sql_99_run_all() -> str:
    root = str(SQL_DIR.resolve()).replace("'", "''")
    return f"""
    /*
        UFC_OPRBP - 99_run_all_in_ssms_sqlcmd_mode.sql

        Optional convenience script.
        In SSMS enable Query -> SQLCMD Mode, then execute this file.
    */
    :r "{root}\\00_create_database.sql"
    :r "{root}\\01_create_schema.sql"
    :r "{root}\\02_create_staging.sql"
    :r "{root}\\03_load_or_import_notes.sql"
    :r "{root}\\04_transform_to_model.sql"
    :r "{root}\\05_views_triggers_transactions.sql"
    :r "{root}\\06_procedures_json.sql"
    :r "{root}\\07_demo_queries.sql"
    """


def readme() -> str:
    return """
    # UFC_OPRBP Projekt

    Relacijska baza podataka u SQL Serveru na temu UFC, izrađena za predmet
    **Odabrana poglavlja relacijskih baza podataka**.

    ## Struktura

    - `data/raw/` - Kaggle CSV datoteke (`UFC.csv`, `event_details.csv`, `fight_details.csv`, `fighter_details.csv`)
    - `sql/` - SQL Server skripte koje se pokreću redom
    - `docs/` - seminarski rad, ER dijagram i bilješke za obranu
    - `tools/` - pomoćni generatori i validacijske skripte

    ## Pokretanje u SSMS-u

    Otvori skripte iz `sql/` i izvrši ih ovim redom:

    1. `00_create_database.sql`
    2. `01_create_schema.sql`
    3. `02_create_staging.sql`
    4. `03_load_or_import_notes.sql`
    5. `04_transform_to_model.sql`
    6. `05_views_triggers_transactions.sql`
    7. `06_procedures_json.sql`
    8. `07_demo_queries.sql`

    Alternativa: otvori `99_run_all_in_ssms_sqlcmd_mode.sql`, ukljuci
    **Query -> SQLCMD Mode** i pokreni sve odjednom.

    Ako `BULK INSERT` u trećoj skripti nema pravo čitati datoteke, u istoj skripti
    promijeni `@RawDataPath` ili koristi SSMS Import Flat File Wizard u tablice
    `stg.EventDetails`, `stg.FightDetails`, `stg.FighterDetails` i `stg.UFCMaster`.

    ## Git

    Repozitorij je inicijaliziran lokalno. Tipični prvi push:

    ```powershell
    git status
    git add .
    git commit -m "Initial UFC database project"
    git branch -M main
    git remote add origin <URL_TVOG_REPOZITORIJA>
    git push -u origin main
    ```

    ## Sto pokazati na obrani

    - Normalizirani model s oko 15 entiteta i staging slojem.
    - Relacije 1:1, 1:N i M:N.
    - SQL upite: `JOIN`, `GROUP BY`, `HAVING`, CTE, window funkciju i paging.
    - Viewove `ufc.v_event_results`, `ufc.v_fighter_summary`, `ufc.v_weight_class_statistics`.
    - Trigger `ufc.trg_Fight_Audit` i tablicu `audit.ChangeLog`.
    - Transakcijski rollback preko `ufc.sp_update_fight_result`.
    - JSON export/import preko `ufc.sp_get_event_card_json` i `ufc.sp_import_fight_result_json`.
    """


def er_mermaid() -> str:
    return """
    erDiagram
        COUNTRY ||--o{ REGION : contains
        REGION ||--o{ CITY : contains
        CITY ||--o{ EVENT : hosts
        EVENT ||--o{ FIGHT : contains
        WEIGHT_CLASS ||--o{ FIGHT : classifies
        FIGHT_FORMAT ||--o{ FIGHT : schedules
        VICTORY_METHOD ||--o{ VICTORY_DETAIL : has
        VICTORY_DETAIL ||--o{ FIGHT : explains
        REFEREE ||--o{ FIGHT : officiates
        STANCE ||--o{ FIGHTER : describes
        FIGHTER ||--|| FIGHTER_CAREER_STATS : has
        FIGHT ||--o{ FIGHT_PARTICIPANT : includes
        FIGHTER ||--o{ FIGHT_PARTICIPANT : competes
        FIGHT_PARTICIPANT ||--|| FIGHT_PERFORMANCE_STATS : records
        FIGHT_PARTICIPANT ||--|| FIGHT_STRIKE_BREAKDOWN : records

        COUNTRY {
          int country_id PK
          nvarchar country_name
        }
        EVENT {
          varchar event_id PK
          nvarchar event_name
          date event_date
          int city_id FK
        }
        FIGHT {
          varchar fight_id PK
          varchar event_id FK
          int weight_class_id FK
          varchar winner_fighter_id FK
        }
        FIGHTER {
          varchar fighter_id PK
          nvarchar fighter_name
          int stance_id FK
        }
        FIGHT_PARTICIPANT {
          varchar fight_id PK,FK
          varchar corner_color PK
          varchar fighter_id FK
        }
    """


def defense_notes() -> str:
    return """
    # Biljeske za obranu

    ## Kratki uvod

    Projekt modelira UFC evente, borbe, borce, rezultate i statistiku borbe.
    Podaci su preuzeti iz Kaggle dataseta `UFC DATASETS 1994-2025`, a prvo se
    uvoze u staging tablice jer CSV sadrzi puno denormaliziranih stupaca.

    ## Sto je koristenje gradiva s predavanja

    - SQL ponavljanje: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `JOIN`, `GROUP BY`, `HAVING`, `ORDER BY`.
    - Pogledi: `ufc.v_event_results`, `ufc.v_fighter_summary`, `ufc.v_weight_class_statistics`.
    - Triggeri: `ufc.trg_Fight_Audit` zapisuje promjene u `audit.ChangeLog`.
    - Transakcije: procedure imaju `BEGIN TRANSACTION`, `COMMIT` i `ROLLBACK`.
    - Procedure: dohvat borbi, usporedba boraca, paging i promjena rezultata.
    - JSON: `FOR JSON PATH`, `ISJSON`, `JSON_VALUE`.

    ## Sto nije koristenje i zasto

    - APEX nije ukljucen jer nije potreban za ovaj projekt i vezan je uz Oracle okruzenje.
    - MongoDB/NoSQL nije ukljucen jer je zadatak napraviti relacijsku bazu u SQL Serveru.
    - Distribuirane baze nisu ukljucene jer je projekt lokalni studentski sustav i nema stvarnu potrebu za horizontalnim skaliranjem.

    ## Demo redoslijed u SSMS-u

    1. Pokazati tablice u shemama `geo`, `ref`, `ufc`, `audit`.
    2. Otvoriti ER dijagram ili `docs/ER_UFC.mmd`.
    3. Pokrenuti view `SELECT TOP 20 * FROM ufc.v_event_results`.
    4. Pokrenuti CTE/window primjere iz `07_demo_queries.sql`.
    5. Pokrenuti rollback demo procedure `sp_import_fight_result_json`.
    6. Pokazati da audit trigger radi kod commita i da rollback ponistava promjenu.
    """


def validation_tool() -> str:
    return r'''
    # -*- coding: utf-8 -*-
    """Print simple row counts and headers for the Kaggle UFC CSV files."""

    from __future__ import annotations

    import csv
    from pathlib import Path


    ROOT = Path(__file__).resolve().parents[1]
    RAW = ROOT / "data" / "raw"


    def main() -> None:
        for path in sorted(RAW.glob("*.csv")):
            with path.open("r", encoding="utf-8-sig", newline="") as f:
                reader = csv.reader(f)
                header = next(reader)
                rows = sum(1 for _ in reader)
            print(f"{path.name}: {rows} rows, {len(header)} columns")
            print("  " + ", ".join(header[:12]) + (" ..." if len(header) > 12 else ""))


    if __name__ == "__main__":
        main()
    '''


def main() -> None:
    SQL_DIR.mkdir(exist_ok=True)
    DOCS_DIR.mkdir(exist_ok=True)

    write(SQL_DIR / "00_create_database.sql", dedent(sql_00_create_database()))
    write(SQL_DIR / "01_create_schema.sql", dedent(sql_01_create_schema()))
    write(SQL_DIR / "02_create_staging.sql", dedent(sql_02_create_staging()))
    write(SQL_DIR / "03_load_or_import_notes.sql", dedent(sql_03_load()))
    write(SQL_DIR / "04_transform_to_model.sql", dedent(sql_04_transform()))
    write(SQL_DIR / "05_views_triggers_transactions.sql", dedent(sql_05_views_triggers()))
    write(SQL_DIR / "06_procedures_json.sql", dedent(sql_06_procedures_json()))
    write(SQL_DIR / "07_demo_queries.sql", dedent(sql_07_demo_queries()))
    write(SQL_DIR / "99_run_all_in_ssms_sqlcmd_mode.sql", dedent(sql_99_run_all()))
    write(ROOT / "README.md", dedent(readme()))
    write(DOCS_DIR / "ER_UFC.mmd", dedent(er_mermaid()))
    write(DOCS_DIR / "obrana-biljeske.md", dedent(defense_notes()))
    write(ROOT / "tools" / "validate_csv.py", dedent(validation_tool()))

    print("Generated SQL, README and defense notes.")


if __name__ == "__main__":
    main()
