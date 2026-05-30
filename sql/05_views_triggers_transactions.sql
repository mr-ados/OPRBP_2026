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
