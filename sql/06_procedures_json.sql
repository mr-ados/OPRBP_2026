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
