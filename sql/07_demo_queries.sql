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
