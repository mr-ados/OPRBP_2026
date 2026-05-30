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
