# Demo za trigger `ufc.trg_Fight_Audit`

```sql
USE UFC_OPRBP;
GO

-- 1) Provjera zadnjih audit zapisa prije demonstracije.
SELECT TOP (5)
    change_log_id,
    schema_name,
    table_name,
    action_name,
    key_value,
    old_values,
    new_values,
    changed_at,
    changed_by
FROM audit.ChangeLog
WHERE schema_name = N'ufc'
  AND table_name = N'Fight'
ORDER BY change_log_id DESC;
GO

-- 2) Sigurni demo u transakciji.
-- UPDATE nad ufc.Fight automatski pokrece trigger ufc.trg_Fight_Audit.
BEGIN TRANSACTION;

DECLARE @DemoFightId VARCHAR(32);

SELECT TOP (1)
    @DemoFightId = fight_id
FROM ufc.Fight
WHERE match_time_sec IS NOT NULL
ORDER BY loaded_at DESC, fight_id;

-- Trenutno stanje borbe prije UPDATE-a.
SELECT
    f.fight_id,
    e.event_name,
    f.finish_round,
    f.match_time_sec,
    f.winner_fighter_id
FROM ufc.Fight f
INNER JOIN ufc.Event e ON e.event_id = f.event_id
WHERE f.fight_id = @DemoFightId;

-- Ovaj UPDATE aktivira trigger.
-- Vrijednost se mijenja samo za 1 sekundu kako bi se jasno vidjela razlika.
UPDATE ufc.Fight
SET match_time_sec = CASE
    WHEN match_time_sec IS NULL THEN 1
    WHEN match_time_sec < 1799 THEN match_time_sec + 1
    ELSE match_time_sec - 1
END
WHERE fight_id = @DemoFightId;

-- Stanje borbe nakon UPDATE-a.
SELECT
    f.fight_id,
    e.event_name,
    f.finish_round,
    f.match_time_sec,
    f.winner_fighter_id
FROM ufc.Fight f
INNER JOIN ufc.Event e ON e.event_id = f.event_id
WHERE f.fight_id = @DemoFightId;

-- 3) Audit zapis koji je trigger upravo napravio.
-- old_values i new_values su JSON zapisi starog i novog stanja retka.
SELECT TOP (1)
    cl.change_log_id,
    cl.action_name,
    cl.key_value AS fight_id,
    old_match_time_sec = JSON_VALUE(cl.old_values, '$.match_time_sec'),
    new_match_time_sec = JSON_VALUE(cl.new_values, '$.match_time_sec'),
    old_winner_fighter_id = JSON_VALUE(cl.old_values, '$.winner_fighter_id'),
    new_winner_fighter_id = JSON_VALUE(cl.new_values, '$.winner_fighter_id'),
    cl.old_values,
    cl.new_values,
    cl.changed_at,
    cl.changed_by
FROM audit.ChangeLog cl
WHERE cl.schema_name = N'ufc'
  AND cl.table_name = N'Fight'
  AND cl.key_value = @DemoFightId
ORDER BY cl.change_log_id DESC;

-- 4) ROLLBACK ponistava i UPDATE i audit zapis jer je trigger dio iste transakcije.
ROLLBACK TRANSACTION;

-- 5) Provjera nakon ROLLBACK-a.
-- Audit zapis iz demonstracije vise ne postoji jer transakcija nije commitana.
SELECT TOP (5)
    change_log_id,
    schema_name,
    table_name,
    action_name,
    key_value,
    old_values,
    new_values,
    changed_at,
    changed_by
FROM audit.ChangeLog
WHERE schema_name = N'ufc'
  AND table_name = N'Fight'
ORDER BY change_log_id DESC;
GO
```

Ako treba da audit zapis ostane trajno u bazi, u demo dijelu zamijeniti:

```sql
ROLLBACK TRANSACTION;
```

s:

```sql
COMMIT TRANSACTION;
```
