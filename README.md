# UFC_OPRBP Projekt

Relacijska baza podataka u SQL Serveru na temu UFC, izrađena za predmet
**Odabrana poglavlja relacijskih baza podataka**.

Projekt koristi Kaggle dataset `UFC DATASETS 1994-2025` i pretvara denormalizirane
CSV podatke u normalizirani relacijski model s oko 15 entiteta.

## Struktura

- `data/raw/` - originalne Kaggle CSV datoteke
- `data/processed/tsv/` - TSV fallback datoteke za SQL Server import
- `sql/` - SQL Server skripte koje se pokreću redom
- `docs/` - ER dijagram i seminarski artefakti

## Pokretanje u SSMS-u

Preporučeni redoslijed:

1. `00_create_database.sql`
2. `01_create_schema.sql`
3. `02_create_staging.sql`
4. `03_load_tsv_compatible.sql`
5. `03b_fix_existing_schema_constraints.sql` ako je baza već bila napravljena prije popravka weight constrainta
6. `04_transform_to_model.sql`
7. `05_views_triggers_transactions.sql`
8. `06_procedures_json.sql`
9. `07_demo_queries.sql`

Alternativa: otvori `99_run_all_in_ssms_sqlcmd_mode.sql`, uključi
**Query -> SQLCMD Mode** i pokreni sve odjednom.

Nakon `03_load_tsv_compatible.sql` očekivani staging brojevi su:

```text
stg.EventDetails      8337
stg.FighterDetails    2611
stg.FightDetails      8337
stg.UFCMaster         8337
```

Nakon `04_transform_to_model.sql` očekivani glavni brojevi su približno:

```text
ufc.Event                  745
ufc.Fighter                2611
ufc.Fight                  8337
ufc.FightParticipant       16674
ufc.FightPerformanceStats  16674
ufc.FightStrikeBreakdown   16674
```

## Problemi i popravci tijekom izrade

### SQL Server nije mogao čitati CSV iz Documents foldera

Prvi `BULK INSERT` je javio:

```text
Cannot bulk load because the file ... could not be opened.
Operating system error code 5(Access is denied.).
```

Razlog: SQL Server ne čita datoteku kao Windows korisnik koji koristi SSMS, nego
kao SQL Server servisni račun. Zato je uveden folder:

```text
C:\SQLImport\UFC\
```

SQL Server servisu je trebalo dati read permission, npr. za default instancu:

```powershell
icacls "C:\SQLImport\UFC" /grant "NT SERVICE\MSSQLSERVER:(OI)(CI)R"
```

### `FORMAT = 'CSV'` nije radio na lokalnoj konfiguraciji

Nakon rješavanja permissiona pojavio se:

```text
Msg 7301
Cannot obtain the required interface ("IID_IColumnsInfo") from OLE DB provider "BULK"
```

Zato je CSV import zamijenjen TSV fallbackom. CSV datoteke su pretvorene u TSV
datoteke u `data/processed/tsv/`, a import se radi preko:

```text
03_load_tsv_compatible.sql
```

U komentaru te skripte wildcard je zapisan kao `'*'.tsv` jer bi `/*.tsv` unutar
SQL block komentara moglo zbuniti SSMS i komentirati ostatak skripte.

### `CK_Fighter_weight` je bio previše strog

Transformacija je prvo pala na constraintu:

```text
CK_Fighter_weight
```

Dataset sadrži povijesnog open-weight borca Emmanuela Yarborougha s težinom
`349.27 kg`. Početno ograničenje do `180 kg` bilo je prekonzervativno, pa je
promijenjeno na:

```sql
weight_kg IS NULL OR weight_kg BETWEEN 35 AND 400
```

Ako je baza napravljena prije te izmjene, pokreće se:

```text
03b_fix_existing_schema_constraints.sql
```

## Što pokazati na obrani

- Normalizirani model s oko 15 entiteta i staging slojem.
- Relacije 1:1, 1:N i M:N.
- Osnovne SQL upite: `SELECT`, `JOIN`, `GROUP BY`, `HAVING`, `ORDER BY`.
- Naprednije upite: CTE, window funkcije, podupite, postotke i rangiranja.
- Viewove `ufc.v_event_results`, `ufc.v_fighter_summary`, `ufc.v_weight_class_statistics`.
- Trigger `ufc.trg_Fight_Audit` i tablicu `audit.ChangeLog`.
- Transakcijski rollback preko `ufc.sp_update_fight_result`.
- JSON export/import preko `ufc.sp_get_event_card_json` i `ufc.sp_import_fight_result_json`.

## Git

Repozitorij je spojen na GitHub remote:

```text
https://github.com/mr-ados/OPRBP_2026.git
```

Za slanje promjena:

```powershell
git status
git add .
git commit -m "Opis promjene"
git push origin main
```
