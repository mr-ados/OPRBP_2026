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
