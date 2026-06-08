# Obrana - UFC_OPRBP

## 1 UVOD

### 1.1 Općenito

Tema projekta je relacijska baza podataka na temu UFC-a. UFC domena je pogodna
za relacijski model jer prirodno sadrži povezane cjeline: evente, borbe, borce,
kategorije, metode pobjede, lokacije, suce i statistiku nastupa.

Glavna ideja:

```text
Sirovi Kaggle dataset sadrži denormalizirane podatke, a projekt ih pretvara u
normalizirani SQL Server model s primarnim ključevima, stranim ključevima,
ograničenjima, viewovima, triggerom, transakcijama, procedurama i JSON-om.
```

### 1.2 Opis projekta

Baza se zove `UFC_OPRBP`. Projekt koristi SQL Server i SSMS. Podaci dolaze iz
Kaggle dataseta `UFC DATASETS 1994-2025`, s datotekama:

- `event_details.csv`
- `fighter_details.csv`
- `fight_details.csv`
- `UFC.csv`

Podaci se prvo učitavaju u staging tablice, a zatim se transformiraju u
normalizirane tablice. Projekt koristi sheme:

- `stg` - sirovi/staging podaci;
- `geo` - geografski podaci;
- `ref` - šifrarnici;
- `ufc` - glavna UFC domena;
- `audit` - audit zapis promjena.

Kratka rečenica za obranu:

```text
Projekt pokazuje put od sirovih CSV/TSV podataka do normalizirane relacijske
baze i demonstrira gradivo iz SQL-a, transakcija, procedura, triggera, viewova
i JSON-a.
```

---

## 2 IZRADA MODELA

### Staging entiteti

- `stg.EventDetails` - staging tablica za podatke o eventima iz izvornog
  dataseta.
- `stg.FightDetails` - staging tablica za podatke o borbama i rezultatima.
- `stg.FighterDetails` - staging tablica za podatke o borcima i karijernim
  statistikama.
- `stg.UFCMaster` - glavna staging tablica koja sadrži denormalizirani spoj
  podataka o eventu, borbi, crvenom/plavom borcu, rezultatu i statistikama.

Staging sloj nije finalni relacijski model. Služi za siguran import i kontrolu
ulaznih podataka.

### `geo` entiteti

- `geo.Country` - država u kojoj se održava event.
- `geo.Region` - regija ili savezna država unutar države.
- `geo.City` - grad u kojem se održava event.

Ovaj dio modela odvaja lokacije od eventa i smanjuje ponavljanje naziva gradova,
regija i država.

### `ref` entiteti

- `ref.Stance` - stav borca, npr. orthodox, southpaw ili switch.
- `ref.WeightClass` - težinska kategorija/divizija, npr. lightweight ili
  welterweight.
- `ref.FightFormat` - format borbe prema broju planiranih rundi.
- `ref.VictoryMethod` - osnovna metoda pobjede, npr. decision, KO/TKO ili
  submission.
- `ref.VictoryDetail` - detalj metode pobjede, npr. unanimous, split ili
  rear-naked choke.
- `ref.Referee` - sudac koji je vodio borbu.

Šifrarnici se nalaze u `ref` shemi zato što se iste vrijednosti ponavljaju u
mnogo borbi.

### `ufc` entiteti

- `ufc.Event` - UFC event ili fight card; sadrži naziv, datum i lokaciju.
- `ufc.Fighter` - borac; sadrži ime, nadimak, fizičke karakteristike, stav i
  datum rođenja.
- `ufc.FighterCareerStats` - karijerne statistike borca, poput pobjeda, poraza,
  prosjeka značajnih udaraca i obrane od rušenja.
- `ufc.Fight` - konkretna borba na eventu; sadrži kategoriju, format, suca,
  metodu pobjede, rundu završetka i pobjednika.
- `ufc.FightParticipant` - nastup borca u konkretnoj borbi; povezuje borca i
  borbu te čuva kut (`Red`/`Blue`) i rezultat nastupa.
- `ufc.FightPerformanceStats` - statistika nastupa borca u borbi: knockdowni,
  značajni udarci, ukupni udarci, rušenja, submission pokušaji i kontrola.
- `ufc.FightStrikeBreakdown` - detaljna razrada udaraca po glavi, tijelu, nozi,
  distanci, klinču i parteru.

### `audit` entitet

- `audit.ChangeLog` - tehnička tablica u koju trigger zapisuje promjene nad
  tablicom `ufc.Fight`. Staro i novo stanje sprema se kao JSON.

---

## 3 RELACIJE

### Geografska hijerarhija

- `geo.Country 1:N geo.Region` - jedna država ima više regija.
- `geo.Region 1:N geo.City` - jedna regija ima više gradova.
- `geo.City 1:N ufc.Event` - jedan grad može ugostiti više evenata.
- `ufc.Event 1:N ufc.Fight` - jedan event ima više borbi.

Sažetak:

```text
Country -> Region -> City -> Event -> Fight
```

Kontrolni popis kardinaliteta:

- `Country 1:N Region`
- `Region 1:N City`
- `City 1:N Event`
- `Event 1:N Fight`

### Veze ref entiteta i borbi

- `ref.WeightClass 1:N ufc.Fight` - jedna kategorija pripada mnogim borbama.
- `ref.FightFormat 1:N ufc.Fight` - jedan format koristi se u mnogim borbama.
- `ref.VictoryMethod 1:N ufc.Fight` - jedna metoda pobjede koristi se u mnogim
  borbama.
- `ref.VictoryMethod 1:N ref.VictoryDetail` - jedna metoda može imati više
  detalja.
- `ref.VictoryDetail 1:N ufc.Fight` - jedan detalj metode može opisivati više
  borbi.
- `ref.Referee 1:N ufc.Fight` - jedan sudac može voditi više borbi.

### Veze boraca

- `ref.Stance 1:N ufc.Fighter` - jedan stav može imati više boraca.
- `ufc.Fighter 1:1 ufc.FighterCareerStats` - jedan borac ima jedan redak
  karijernih statistika.
- `ufc.Fight 1:N ufc.FightParticipant` - jedna borba ima više sudionika.
- `ufc.Fighter 1:N ufc.FightParticipant` - jedan borac može imati više nastupa.
- `ufc.Fighter N:M ufc.Fight` - konceptualna M:N veza riješena je preko
  međutablice `ufc.FightParticipant`.

### Veze statistika

- `ufc.FightParticipant 1:1 ufc.FightPerformanceStats` - jedan nastup ima jedan
  skup glavnih statistika.
- `ufc.FightParticipant 1:1 ufc.FightStrikeBreakdown` - jedan nastup ima jednu
  detaljnu razradu udaraca.

Kontrolni popis kardinaliteta:

- `FightParticipant 1:1 FightPerformanceStats`
- `FightParticipant 1:1 FightStrikeBreakdown`


---

## 4 LOGIČKI I RELACIJSKI MODEL

Logički model prikazuje glavne entitete i njihove odnose. Relacijski model te
odnose pretvara u tablice, primarne ključeve, strane ključeve i ograničenja.

Najvažniji ključevi:

- `ufc.Event.event_id` - primarni ključ eventa.
- `ufc.Fight.fight_id` - primarni ključ borbe.
- `ufc.Fighter.fighter_id` - primarni ključ borca.
- `ufc.FightParticipant (fight_id, corner_color)` - složeni primarni ključ
  sudionika borbe.
- `ufc.FightPerformanceStats (fight_id, corner_color)` - isti ključ kao kod
  sudionika, jer statistika pripada nastupu.
- `ufc.FightStrikeBreakdown (fight_id, corner_color)` - isti ključ kao kod
  sudionika, jer detaljna statistika pripada nastupu.

Primjer M:N veze u relacijskom modelu:

```sql
CREATE TABLE ufc.FightParticipant
(
    fight_id VARCHAR(32) NOT NULL,
    corner_color VARCHAR(8) NOT NULL,
    fighter_id VARCHAR(32) NOT NULL,
    is_winner BIT NOT NULL,
    result_label NVARCHAR(40) NOT NULL,
    CONSTRAINT PK_FightParticipant PRIMARY KEY (fight_id, corner_color),
    CONSTRAINT FK_FightParticipant_Fight
        FOREIGN KEY (fight_id) REFERENCES ufc.Fight(fight_id),
    CONSTRAINT FK_FightParticipant_Fighter
        FOREIGN KEY (fighter_id) REFERENCES ufc.Fighter(fighter_id)
);
```

Ovaj primjer pokazuje kako se borba i borac povezuju preko međutablice.

---

## 5 IZRADA BAZE PODATAKA PREMA MODELU

Skripte se pokreću redom:

1. `00_create_database.sql` - stvara bazu `UFC_OPRBP`.
2. `01_create_schema.sql` - stvara sheme, tablice, ključeve i ograničenja.
3. `02_create_staging.sql` - stvara staging tablice.
4. `03_load_tsv_compatible.sql` - učitava TSV podatke.
5. `03b_fix_existing_schema_constraints.sql` - popravlja constraint težine ako
   je baza već bila ranije napravljena.
6. `04_transform_to_model.sql` - transformira staging podatke u normalizirani
   model.
7. `05_views_triggers_transactions.sql` - stvara viewove, trigger i rollback
   demo.
8. `06_procedures_json.sql` - stvara procedure i JSON primjere.
9. `07_demo_queries.sql` - sadrži demonstracijske upite.

Praktični problemi tijekom izrade:

- SQL Server servisni račun nije imao pravo čitanja nad izvornim datotekama.
- `BULK INSERT FORMAT = 'CSV'` nije radio stabilno u lokalnoj konfiguraciji.
- Uveden je TSV fallback import.
- Constraint za težinu borca proširen je do `400 kg` zbog povijesnog open-weight
  podatka.

---

## 6 UPITI NA BAZU PODATAKA

Svaki upit iz `07_demo_queries.sql` prikazan je kao zaseban isječak.

### 6.1 Osnovni dohvat evenata

Upit dohvaća zadnjih 20 UFC evenata i demonstrira `SELECT`, `TOP` i `ORDER BY`.

```sql
SELECT TOP (20)
    event_date,
    event_name,
    location_raw
FROM ufc.Event
ORDER BY event_date DESC;
```

### 6.2 Provjera svih divizija

Upit prikazuje sve težinske kategorije i oznake za ženske, interim i catchweight
kategorije.

```sql
SELECT
    division_name,
    is_women,
    is_interim,
    is_catch_weight
FROM ref.WeightClass
ORDER BY division_name;
```

### 6.3 Prosječan broj borbi po eventu

Upit prvo broji borbe po eventu, a zatim računa prosjek, minimum, maksimum i
broj evenata.

```sql
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
```

### 6.4 Abu Dhabi eventi

Upit filtrira evente prema lokaciji i prikazuje sve evente održane u Abu Dhabiju.

```sql
SELECT
    event_date,
    event_name,
    location_raw
FROM ufc.Event
WHERE location_raw LIKE N'%Abu Dhabi%'
ORDER BY event_date DESC;
```

### 6.5 JOIN preko viewa rezultata

Upit koristi `ufc.v_event_results` kako bi prikazao borbe u SAD-u s oba borca,
pobjednikom i metodom pobjede.

```sql
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
```

### 6.6 `GROUP BY` i `HAVING`

Upit pronalazi kategorije s barem 100 borbi.

```sql
SELECT
    division_name,
    COUNT(*) AS fight_count
FROM ufc.v_event_results
GROUP BY division_name
HAVING COUNT(*) >= 100
ORDER BY fight_count DESC;
```

### 6.7 DML naredbe unutar rollback transakcije

Upit demonstrira `INSERT`, `UPDATE` i `DELETE`, ali sve se poništava pomoću
`ROLLBACK TRANSACTION`.

```sql
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
```

### 6.8 Odabir eventa s mnogo završenih borbi

Upit sprema u varijablu event koji ima najviše borbi završenih prije odluke
sudaca.

```sql
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
```

### 6.9 Sve završene borbe s odabranog eventa

Upit prikazuje borbe s odabranog eventa koje nisu završile odlukom sudaca.

```sql
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
```

### 6.10 Pobjednici završenih borbi s odabranog eventa

Upit izdvaja samo pobjednike iz završenih borbi na odabranom eventu.

```sql
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
```

### 6.11 CTE - najbolji finisheri

Upit koristi CTE za brojanje pobjeda koje nisu završile odlukom sudaca.

```sql
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
```

### 6.12 Window funkcija - rangiranje po diviziji

Upit koristi `DENSE_RANK()` za rangiranje boraca prema broju pobjeda unutar
svake divizije.

```sql
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
```

### 6.13 Podupit - eventi veći od prosjeka

Upit prikazuje evente koji imaju više borbi od prosječnog eventa.

```sql
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
```

### 6.14 Svi pogođeni značajni udarci

Upit pronalazi nastupe u kojima je borac pogodio svaki pokušani značajni udarac.

```sql
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
```

### 6.15 Sva pogođena rušenja

Upit pronalazi nastupe u kojima je borac pogodio svako pokušano rušenje.

```sql
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
```

### 6.16 Pobjednik s jednim pokušanim značajnim udarcem

Upit prikazuje borbe u kojima je pobjednik pokušao točno jedan značajni udarac.

```sql
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
```

### 6.17 Pobjednici s manje pogođenih značajnih udaraca

Upit uspoređuje pobjednika i protivnika u istoj borbi te pronalazi pobjede s
manje pogođenih značajnih udaraca od protivnika.

```sql
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
```

### 6.18 Raspodjela metoda pobjede po diviziji

Upit računa broj i postotak metoda pobjede unutar svake divizije.

```sql
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
```

### 6.19 Najbrži finishevi po diviziji

Upit računa ukupno vrijeme završetka borbe i rangira najbrže finisheve po
diviziji.

```sql
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
```

### 6.20 Borci s najviše nastupa i postotkom pobjeda

Upit prikazuje borce s barem 10 nastupa i računa postotak pobjeda.

```sql
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
```

### 6.21 Godišnji trend evenata i borbi

Upit grupira podatke po godini i računa broj evenata, borbi i prosječan broj
borbi po eventu.

```sql
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
```

### 6.22 Ishodi title fightova po metodi

Upit prikazuje metode pobjede u borbama za titulu.

```sql
SELECT
    method,
    title_fights = COUNT(*),
    avg_finish_round = AVG(CONVERT(DECIMAL(10,2), finish_round))
FROM ufc.v_event_results
WHERE is_title_fight = 1
GROUP BY method
ORDER BY title_fights DESC;
```

### 6.23 Pobjede s visokom kontrolom

Upit pronalazi pobjede s najmanje 300 sekundi kontrole, što je zanimljivo za
grappling stil borbe.

```sql
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
```

### 6.24 `OFFSET/FETCH` paging

Upit poziva proceduru koja vraća stranicu rezultata za lightweight diviziju.

```sql
EXEC ufc.sp_fights_paging @division_name = N'lightweight', @skip = 0, @getRows = 10;
```

### 6.25 JSON export zadnjeg eventa

Upit pronalazi najnoviji event i vraća njegov fight card u JSON obliku.

```sql
DECLARE @LatestEventId VARCHAR(32) =
(
    SELECT TOP (1) event_id
    FROM ufc.Event
    ORDER BY event_date DESC
);
EXEC ufc.sp_get_event_card_json @event_id = @LatestEventId;
```

### 6.26 JSON input i rollback demo

Upit gradi JSON payload s borbom i pobjednikom, provjerava JSON funkcije i
poziva proceduru s rollbackom.

```sql
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
```

### 6.27 Acceptance checks

Upit provjerava moguće probleme: borbe bez dva sudionika, orphan sudionike i
nelogične statistike udaraca/rušenja.

```sql
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
```

---

## 7 POGLEDI, TRIGGERI, TRANSAKCIJE, PROCEDURE I JSON

### 7.1 Pogledi

Projekt koristi tri glavna viewa:

- `ufc.v_event_results` - spaja evente, borbe, borce, lokacije, divizije i
  metode pobjede.
- `ufc.v_fighter_summary` - prikazuje sažetak borca i agregirane podatke iz
  nastupa.
- `ufc.v_weight_class_statistics` - prikazuje statistiku po divizijama.

Primjer korištenja viewa:

```sql
SELECT TOP (20) *
FROM ufc.v_event_results
ORDER BY event_date DESC, fight_id DESC;
```

Objašnjenje:

```text
View olakšava demonstraciju jer skriva dugačke JOIN upite i daje čitljiv prikaz
rezultata.
```

### 7.2 Trigger i audit

Trigger `ufc.trg_Fight_Audit` automatski zapisuje promjene nad `ufc.Fight` u
`audit.ChangeLog`.

Kratki isječak:

```sql
CREATE TRIGGER ufc.trg_Fight_Audit
ON ufc.Fight
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    INSERT INTO audit.ChangeLog
        (schema_name, table_name, action_name, key_value, old_values, new_values)
    SELECT
        N'ufc',
        N'Fight',
        CASE
            WHEN i.fight_id IS NOT NULL AND d.fight_id IS NOT NULL THEN 'UPDATE'
            WHEN i.fight_id IS NOT NULL THEN 'INSERT'
            ELSE 'DELETE'
        END,
        COALESCE(i.fight_id, d.fight_id),
        old_values = CASE WHEN d.fight_id IS NULL THEN NULL ELSE
            (SELECT d.fight_id, d.winner_fighter_id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        END,
        new_values = CASE WHEN i.fight_id IS NULL THEN NULL ELSE
            (SELECT i.fight_id, i.winner_fighter_id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        END
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.fight_id = i.fight_id;
END;
```

Provjera audit zapisa:

```sql
SELECT TOP (10) *
FROM audit.ChangeLog
ORDER BY changed_at DESC;
```

### 7.3 Transakcije

Transakcija se koristi kod promjene rezultata borbe. Promjena se potvrđuje s
`COMMIT` ili poništava s `ROLLBACK`.

Kratki isječak iz procedure:

```sql
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE ufc.Fight
    SET winner_fighter_id = @winner_fighter_id
    WHERE fight_id = @fight_id;

    UPDATE ufc.FightParticipant
    SET is_winner = CASE WHEN fighter_id = @winner_fighter_id THEN 1 ELSE 0 END
    WHERE fight_id = @fight_id;

    IF @commit_changes = 1
        COMMIT TRANSACTION;
    ELSE
        ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

Objašnjenje:

```text
Transakcija osigurava da se rezultat borbe i status sudionika promijene kao
jedna cjelina. Ako se promjena ne potvrdi, stanje baze ostaje nepromijenjeno.
```

### 7.4 Procedure

Procedure u projektu:

- `ufc.sp_get_event_fights` - dohvat borbi po eventu ili nazivu eventa.
- `ufc.sp_compare_fighters` - usporedba dva borca.
- `ufc.sp_fights_paging` - straničenje rezultata pomoću `OFFSET/FETCH`.
- `ufc.sp_update_fight_result` - transakcijska promjena rezultata borbe.
- `ufc.sp_get_event_card_json` - JSON export event carda.
- `ufc.sp_import_fight_result_json` - JSON input i poziv transakcijske procedure.

Primjer procedure za paging:

```sql
CREATE PROCEDURE ufc.sp_fights_paging
    @division_name NVARCHAR(120) = NULL,
    @skip INT = 0,
    @getRows INT = 20
AS
BEGIN
    SELECT
        event_date, event_name, division_name, red_fighter, blue_fighter,
        winner, method, method_detail, finish_round, match_time_sec
    FROM ufc.v_event_results
    WHERE (@division_name IS NULL OR division_name = @division_name)
    ORDER BY event_date DESC, event_name, fight_id
    OFFSET @skip ROWS
    FETCH NEXT @getRows ROWS ONLY;
END;
```

### 7.5 JSON

JSON se koristi za export event carda, import rezultata borbe i audit promjena.

`FOR JSON PATH` primjer:

```sql
SELECT
    e.event_id,
    e.event_name,
    fights =
    (
        SELECT vr.fight_id, vr.red_fighter, vr.blue_fighter, vr.winner
        FROM ufc.v_event_results vr
        WHERE vr.event_id = e.event_id
        FOR JSON PATH
    )
FROM ufc.Event e
WHERE e.event_id = @event_id
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
```

`ISJSON` i `JSON_VALUE` primjer:

```sql
IF ISJSON(@payload) <> 1
    THROW 52000, 'Payload must be valid JSON.', 1;

DECLARE @fight_id VARCHAR(32) = JSON_VALUE(@payload, '$.fight_id');
DECLARE @winner_fighter_id VARCHAR(32) = JSON_VALUE(@payload, '$.winner_fighter_id');
```

Kratka rečenica:

```text
Podaci ostaju relacijski, a JSON služi kao format razmjene podataka i kao
praktičan oblik audit zapisa.
```

---

## 8 KORIŠTENO I NEKORIŠTENO S PREDAVANJA

### Korišteno

- SQL Server i SSMS.
- DDL: `CREATE DATABASE`, `CREATE SCHEMA`, `CREATE TABLE`.
- DML: `INSERT`, `UPDATE`, `DELETE`.
- DQL: `SELECT`, `JOIN`, `GROUP BY`, `HAVING`, `ORDER BY`.
- Primarni ključevi, strani ključevi, `UNIQUE` i `CHECK` ograničenja.
- Normalizacija i relacije 1:1, 1:N i N:M.
- CTE, podupiti i window funkcije.
- Viewovi.
- Triggeri.
- Transakcije.
- Pohranjene procedure.
- JSON funkcionalnosti u SQL Serveru.

### Nije korišteno

- APEX nije korišten jer je vezan uz Oracle okruženje, a projekt je rađen u SQL
  Serveru.
- MongoDB/NoSQL nije korišten jer je zadatak relacijska baza podataka.
- Distribuirane baze nisu korištene jer projekt radi lokalno i nema potrebu za
  više servera ili replikacijom.

---

## 9 ZAKLJUČAK

Projekt prikazuje potpun proces izrade relacijske baze: import sirovih podataka,
normalizaciju, izradu relacija, dodavanje ograničenja, izradu viewova, triggera,
transakcija, procedura, JSON primjera i demonstracijskih upita.

Najvažnije za završnu rečenicu:

```text
Vrijednost projekta je u tome što se stvarni denormalizirani sportski dataset
pretvara u obranjiv relacijski model s jasnim entitetima, relacijama i SQL
objektima iz gradiva.
```

---

## Brzi odgovori na moguća pitanja

### Zašto postoji staging sloj?

Staging sloj postoji zato što su ulazni CSV/TSV podaci denormalizirani. Podaci
se prvo učitavaju u sirovom obliku, a zatim se transformiraju u relacijski
model.

### Zašto postoje sheme?

Sheme odvajaju tehničke staging tablice, geografske podatke, šifrarnike, glavnu
UFC domenu i audit log.

### Zašto je `FightParticipant` važan?

`FightParticipant` rješava M:N vezu između boraca i borbi. Jedan borac može
nastupiti u mnogo borbi, a jedna borba ima više sudionika.

### Zašto statistike nisu u `Fight`?

Statistike pripadaju nastupu pojedinog borca, a ne borbi kao cjelini. Zato su
povezane preko `fight_id` i `corner_color`.

### Što radi trigger?

Trigger automatski zapisuje promjene nad `ufc.Fight` u `audit.ChangeLog`.

### Što pokazuje transakcija?

Transakcija pokazuje da se promjena rezultata borbe može potvrditi ili poništiti
kao jedna cjelina.

### Zašto JSON u relacijskoj bazi?

JSON služi za razmjenu podataka s aplikacijama i za audit zapise, dok glavni
model ostaje relacijski.
