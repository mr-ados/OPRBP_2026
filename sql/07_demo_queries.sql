/*
    UFC_OPRBP - 07_demo_queries.sql
    Basic and advanced queries for screenshots and oral defense.

    If 04, 05 and 06 already ran successfully, changes in this file do not
    require rerunning them. Just execute this script again.
*/
USE UFC_OPRBP;
GO

-- 1) Basic SELECT + ORDER BY: recent UFC events.
SELECT TOP (20)
    event_date,
    event_name,
    location_raw
FROM ufc.Event
ORDER BY event_date DESC;

-- 2) Simple check: all division names in the dataset.
SELECT
    division_name,
    is_women,
    is_interim,
    is_catch_weight
FROM ref.WeightClass
ORDER BY division_name;

-- 3) Easy aggregate: average number of fights per fight card.
SELECT
    avg_fights_per_card = AVG(CONVERT(DECIMAL(10,2), fights_per_card)),
    min_fights_per_card = MIN(fights_per_card),
    max_fights_per_card = MAX(fights_per_card),
    event_count = COUNT(*)
FROM
(
    SELECT event_id, COUNT(*) AS fights_per_card
    FROM ufc.Fight
    GROUP BY event_id
) cards;

-- 4) Location filter: all Abu Dhabi events.
SELECT
    event_date,
    event_name,
    location_raw
FROM ufc.Event
WHERE location_raw LIKE N'%Abu Dhabi%'
ORDER BY event_date DESC;

-- 5) JOIN: fights with both fighters and result.
SELECT TOP (30)
    event_date,
    event_name,
    division_name,
    red_fighter,
    blue_fighter,
    winner,
    method,
    finish_round
FROM ufc.v_event_results
WHERE country = N'USA'
ORDER BY event_date DESC;

-- 6) GROUP BY + HAVING: weight classes with many fights.
SELECT
    division_name,
    COUNT(*) AS fight_count
FROM ufc.v_event_results
GROUP BY division_name
HAVING COUNT(*) >= 100
ORDER BY fight_count DESC;

-- 7) INSERT, UPDATE, DELETE inside transaction so the demo leaves no permanent data.
BEGIN TRANSACTION;
    INSERT INTO ref.Referee (referee_name) VALUES (N'Demo Referee');
    UPDATE ref.Referee
    SET referee_name = N'Demo Referee Updated'
    WHERE referee_name = N'Demo Referee';

    SELECT *
    FROM ref.Referee
    WHERE referee_name LIKE N'Demo Referee%';

    DELETE FROM ref.Referee
    WHERE referee_name = N'Demo Referee Updated';
ROLLBACK TRANSACTION;

-- 8) Pick one event with many finishes for the next two event-specific queries.
DECLARE @FinishEventId VARCHAR(32) =
(
    SELECT TOP (1)
        event_id
    FROM ufc.v_event_results
    WHERE method IS NOT NULL
      AND method <> N'Decision'
      AND method <> N'Overturned'
    GROUP BY event_id
    ORDER BY COUNT(*) DESC, MAX(event_date) DESC
);

SELECT
    selected_event_id = @FinishEventId,
    selected_event_name = MAX(event_name),
    selected_event_date = MAX(event_date),
    finished_fights = COUNT(*)
FROM ufc.v_event_results
WHERE event_id = @FinishEventId
  AND method <> N'Decision'
  AND method <> N'Overturned';

-- 9) All fights from the selected event that ended in a finish.
SELECT
    event_date,
    event_name,
    division_name,
    red_fighter,
    blue_fighter,
    winner,
    method,
    method_detail,
    finish_round,
    match_time_sec
FROM ufc.v_event_results
WHERE event_id = @FinishEventId
  AND method <> N'Decision'
  AND method <> N'Overturned'
ORDER BY finish_round, match_time_sec;

-- 10) Fight winners from the selected event's finished fights.
SELECT
    event_name,
    winner,
    division_name,
    method,
    finish_round,
    match_time_sec
FROM ufc.v_event_results
WHERE event_id = @FinishEventId
  AND winner IS NOT NULL
  AND method <> N'Decision'
  AND method <> N'Overturned'
ORDER BY winner;

-- 11) CTE: top finishers by non-decision wins in the dataset.
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
      AND vm.method_name <> N'Overturned'
    GROUP BY fp.fighter_id, fi.fighter_name
)
SELECT TOP (15) *
FROM fighter_finishes
ORDER BY finish_wins DESC, fighter_name;

-- 12) Window function: rank fighters by wins inside each weight class.
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

-- 13) Subquery: events with more fights than average event size.
SELECT
    e.event_name,
    e.event_date,
    COUNT(f.fight_id) AS fights_on_card
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

-- 14) Fighters who landed every significant strike they attempted.
SELECT TOP (50)
    e.event_date,
    e.event_name,
    fi.fighter_name,
    fp.corner_color,
    ps.significant_strikes_landed,
    ps.significant_strikes_attempted,
    fp.result_label
FROM ufc.FightPerformanceStats ps
INNER JOIN ufc.FightParticipant fp ON fp.fight_id = ps.fight_id AND fp.corner_color = ps.corner_color
INNER JOIN ufc.Fighter fi ON fi.fighter_id = fp.fighter_id
INNER JOIN ufc.Fight f ON f.fight_id = fp.fight_id
INNER JOIN ufc.Event e ON e.event_id = f.event_id
WHERE ps.significant_strikes_attempted > 0
  AND ps.significant_strikes_landed = ps.significant_strikes_attempted
ORDER BY ps.significant_strikes_attempted DESC, e.event_date DESC;

-- 15) Fighters who landed every takedown they attempted.
SELECT TOP (50)
    e.event_date,
    e.event_name,
    fi.fighter_name,
    fp.corner_color,
    ps.takedowns_landed,
    ps.takedowns_attempted,
    fp.result_label
FROM ufc.FightPerformanceStats ps
INNER JOIN ufc.FightParticipant fp ON fp.fight_id = ps.fight_id AND fp.corner_color = ps.corner_color
INNER JOIN ufc.Fighter fi ON fi.fighter_id = fp.fighter_id
INNER JOIN ufc.Fight f ON f.fight_id = fp.fight_id
INNER JOIN ufc.Event e ON e.event_id = f.event_id
WHERE ps.takedowns_attempted > 0
  AND ps.takedowns_landed = ps.takedowns_attempted
ORDER BY ps.takedowns_attempted DESC, e.event_date DESC;

-- 16) Fights where the winner attempted exactly one significant strike.
SELECT
    vr.event_date,
    vr.event_name,
    vr.division_name,
    fi.fighter_name AS winner_name,
    vr.red_fighter,
    vr.blue_fighter,
    ps.significant_strikes_landed,
    ps.significant_strikes_attempted,
    vr.method,
    vr.finish_round,
    vr.match_time_sec
FROM ufc.FightParticipant fp
INNER JOIN ufc.Fighter fi ON fi.fighter_id = fp.fighter_id
INNER JOIN ufc.FightPerformanceStats ps ON ps.fight_id = fp.fight_id AND ps.corner_color = fp.corner_color
INNER JOIN ufc.v_event_results vr ON vr.fight_id = fp.fight_id
WHERE fp.is_winner = 1
  AND ps.significant_strikes_attempted = 1
ORDER BY vr.event_date DESC;

-- 17) Winners who landed fewer significant strikes than their opponent.
SELECT TOP (50)
    vr.event_date,
    vr.event_name,
    vr.division_name,
    winner = winner_f.fighter_name,
    opponent = opponent_f.fighter_name,
    winner_sig_landed = winner_ps.significant_strikes_landed,
    opponent_sig_landed = opponent_ps.significant_strikes_landed,
    vr.method,
    vr.finish_round
FROM ufc.FightParticipant winner_fp
INNER JOIN ufc.FightParticipant opponent_fp
    ON opponent_fp.fight_id = winner_fp.fight_id
   AND opponent_fp.corner_color <> winner_fp.corner_color
INNER JOIN ufc.Fighter winner_f ON winner_f.fighter_id = winner_fp.fighter_id
INNER JOIN ufc.Fighter opponent_f ON opponent_f.fighter_id = opponent_fp.fighter_id
INNER JOIN ufc.FightPerformanceStats winner_ps
    ON winner_ps.fight_id = winner_fp.fight_id AND winner_ps.corner_color = winner_fp.corner_color
INNER JOIN ufc.FightPerformanceStats opponent_ps
    ON opponent_ps.fight_id = opponent_fp.fight_id AND opponent_ps.corner_color = opponent_fp.corner_color
INNER JOIN ufc.v_event_results vr ON vr.fight_id = winner_fp.fight_id
WHERE winner_fp.is_winner = 1
  AND winner_ps.significant_strikes_landed < opponent_ps.significant_strikes_landed
ORDER BY vr.event_date DESC;

-- 18) Method distribution by division with percentages.
WITH method_counts AS
(
    SELECT
        division_name,
        method,
        fight_count = COUNT(*)
    FROM ufc.v_event_results
    WHERE division_name IS NOT NULL
      AND method IS NOT NULL
    GROUP BY division_name, method
)
SELECT
    division_name,
    method,
    fight_count,
    pct_in_division = CONVERT(DECIMAL(6,2), 100.0 * fight_count / SUM(fight_count) OVER (PARTITION BY division_name))
FROM method_counts
ORDER BY division_name, fight_count DESC;

-- 19) Fastest finishes by division.
WITH finish_times AS
(
    SELECT
        division_name,
        event_date,
        event_name,
        red_fighter,
        blue_fighter,
        winner,
        method,
        total_finish_seconds = ((finish_round - 1) * 300) + match_time_sec
    FROM ufc.v_event_results
    WHERE method <> N'Decision'
      AND method <> N'Overturned'
      AND finish_round IS NOT NULL
      AND match_time_sec IS NOT NULL
),
ranked AS
(
    SELECT
        *,
        finish_rank = ROW_NUMBER() OVER (PARTITION BY division_name ORDER BY total_finish_seconds ASC, event_date DESC)
    FROM finish_times
)
SELECT
    division_name,
    event_date,
    event_name,
    red_fighter,
    blue_fighter,
    winner,
    method,
    total_finish_seconds
FROM ranked
WHERE finish_rank <= 3
ORDER BY division_name, finish_rank;

-- 20) Fighters with the most dataset appearances and win percentage.
SELECT TOP (30)
    fi.fighter_name,
    fights = COUNT(*),
    wins = SUM(CASE WHEN fp.is_winner = 1 THEN 1 ELSE 0 END),
    losses = SUM(CASE WHEN fp.result_label = N'Loss' THEN 1 ELSE 0 END),
    draw_nc = SUM(CASE WHEN fp.result_label = N'Draw/NC' THEN 1 ELSE 0 END),
    win_pct = CONVERT(DECIMAL(6,2), 100.0 * SUM(CASE WHEN fp.is_winner = 1 THEN 1 ELSE 0 END) / COUNT(*))
FROM ufc.FightParticipant fp
INNER JOIN ufc.Fighter fi ON fi.fighter_id = fp.fighter_id
GROUP BY fi.fighter_name
HAVING COUNT(*) >= 10
ORDER BY fights DESC, win_pct DESC;

-- 21) Yearly UFC event/fight trend.
SELECT
    event_year = YEAR(e.event_date),
    event_count = COUNT(DISTINCT e.event_id),
    fight_count = COUNT(f.fight_id),
    avg_fights_per_event = CONVERT(DECIMAL(10,2), 1.0 * COUNT(f.fight_id) / COUNT(DISTINCT e.event_id))
FROM ufc.Event e
INNER JOIN ufc.Fight f ON f.event_id = e.event_id
WHERE e.event_date IS NOT NULL
GROUP BY YEAR(e.event_date)
ORDER BY event_year;

-- 22) Title fight outcomes by method.
SELECT
    method,
    title_fights = COUNT(*),
    avg_finish_round = AVG(CONVERT(DECIMAL(10,2), finish_round))
FROM ufc.v_event_results
WHERE is_title_fight = 1
GROUP BY method
ORDER BY title_fights DESC;

-- 23) High-control grappling wins.
SELECT TOP (30)
    vr.event_date,
    vr.event_name,
    vr.division_name,
    winner = fi.fighter_name,
    ps.control_seconds,
    ps.takedowns_landed,
    ps.submission_attempts,
    vr.method,
    vr.finish_round
FROM ufc.FightParticipant fp
INNER JOIN ufc.Fighter fi ON fi.fighter_id = fp.fighter_id
INNER JOIN ufc.FightPerformanceStats ps ON ps.fight_id = fp.fight_id AND ps.corner_color = fp.corner_color
INNER JOIN ufc.v_event_results vr ON vr.fight_id = fp.fight_id
WHERE fp.is_winner = 1
  AND ps.control_seconds >= 300
ORDER BY ps.control_seconds DESC, vr.event_date DESC;

-- 24) OFFSET/FETCH paging through recent lightweight fights.
EXEC ufc.sp_fights_paging @division_name = N'lightweight', @skip = 0, @getRows = 10;

-- 25) JSON export for the latest event in the dataset.
DECLARE @LatestEventId VARCHAR(32) =
(
    SELECT TOP (1) event_id
    FROM ufc.Event
    ORDER BY event_date DESC
);
EXEC ufc.sp_get_event_card_json @event_id = @LatestEventId;

-- 26) JSON input + transaction rollback demo with readable fighter and fight labels.
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

DECLARE @DemoWinnerName NVARCHAR(200) =
(
    SELECT fighter_name
    FROM ufc.Fighter
    WHERE fighter_id = @DemoWinnerId
);

DECLARE @DemoFightLabel NVARCHAR(700) =
(
    SELECT CONCAT(event_name, N': ', red_fighter, N' vs ', blue_fighter)
    FROM ufc.v_event_results
    WHERE fight_id = @DemoFightId
);

DECLARE @Payload NVARCHAR(MAX) =
(
    SELECT
        @DemoFightId AS fight_id,
        @DemoFightLabel AS fight_label,
        @DemoWinnerId AS winner_fighter_id,
        @DemoWinnerName AS winner_fighter_name,
        N'Decision' AS method_name,
        N'Unanimous' AS detail_name,
        3 AS finish_round,
        300 AS match_time_sec
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
);

SELECT
    @Payload AS json_payload,
    ISJSON(@Payload) AS is_valid_json,
    JSON_VALUE(@Payload, '$.winner_fighter_name') AS winner_name_from_json,
    JSON_VALUE(@Payload, '$.fight_label') AS fight_label_from_json;

EXEC ufc.sp_import_fight_result_json @payload = @Payload, @commit_changes = 0;

-- 27) Acceptance checks.
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
