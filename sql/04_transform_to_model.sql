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
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.kd, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.sig_str_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.sig_str_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.sig_str_acc, N'')),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.total_str_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.total_str_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.total_str_acc, N'')),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.td_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.td_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.td_acc, N'')),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.sub_att, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.ctrl, N'')))
FROM stg.UFCMaster m
CROSS APPLY (VALUES
    (N'Red', m.r_kd, m.r_sig_str_landed, m.r_sig_str_atmpted, m.r_sig_str_acc, m.r_total_str_landed, m.r_total_str_atmpted, m.r_total_str_acc, m.r_td_landed, m.r_td_atmpted, m.r_td_acc, m.r_sub_att, m.r_ctrl),
    (N'Blue', m.b_kd, m.b_sig_str_landed, m.b_sig_str_atmpted, m.b_sig_str_acc, m.b_total_str_landed, m.b_total_str_atmpted, m.b_total_str_acc, m.b_td_landed, m.b_td_atmpted, m.b_td_acc, m.b_sub_att, m.b_ctrl)
) v(corner_color, kd, sig_str_landed, sig_str_atmpted, sig_str_acc, total_str_landed, total_str_atmpted, total_str_acc, td_landed, td_atmpted, td_acc, sub_att, ctrl)
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
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.head_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.head_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.head_acc, N'')),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.body_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.body_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.body_acc, N'')),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.leg_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.leg_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.leg_acc, N'')),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.dist_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.dist_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.dist_acc, N'')),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.clinch_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.clinch_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.clinch_acc, N'')),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.ground_landed, N''))),
    CONVERT(INT, TRY_CONVERT(DECIMAL(18,2), NULLIF(v.ground_atmpted, N''))),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.ground_acc, N'')),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.landed_head_per, N'')),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.landed_body_per, N'')),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.landed_leg_per, N'')),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.landed_dist_per, N'')),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.landed_clinch_per, N'')),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(v.landed_ground_per, N''))
FROM stg.UFCMaster m
CROSS APPLY (VALUES
    (N'Red', m.r_head_landed, m.r_head_atmpted, m.r_head_acc, m.r_body_landed, m.r_body_atmpted, m.r_body_acc, m.r_leg_landed, m.r_leg_atmpted, m.r_leg_acc, m.r_dist_landed, m.r_dist_atmpted, m.r_dist_acc, m.r_clinch_landed, m.r_clinch_atmpted, m.r_clinch_acc, m.r_ground_landed, m.r_ground_atmpted, m.r_ground_acc, m.r_landed_head_per, m.r_landed_body_per, m.r_landed_leg_per, m.r_landed_dist_per, m.r_landed_clinch_per, m.r_landed_ground_per),
    (N'Blue', m.b_head_landed, m.b_head_atmpted, m.b_head_acc, m.b_body_landed, m.b_body_atmpted, m.b_body_acc, m.b_leg_landed, m.b_leg_atmpted, m.b_leg_acc, m.b_dist_landed, m.b_dist_atmpted, m.b_dist_acc, m.b_clinch_landed, m.b_clinch_atmpted, m.b_clinch_acc, m.b_ground_landed, m.b_ground_atmpted, m.b_ground_acc, m.b_landed_head_per, m.b_landed_body_per, m.b_landed_leg_per, m.b_landed_dist_per, m.b_landed_clinch_per, m.b_landed_ground_per)
) v(corner_color, head_landed, head_atmpted, head_acc, body_landed, body_atmpted, body_acc, leg_landed, leg_atmpted, leg_acc, dist_landed, dist_atmpted, dist_acc, clinch_landed, clinch_atmpted, clinch_acc, ground_landed, ground_atmpted, ground_acc, landed_head_per, landed_body_per, landed_leg_per, landed_dist_per, landed_clinch_per, landed_ground_per)
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
