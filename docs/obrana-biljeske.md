# Biljeske za obranu

## Kratki uvod

Projekt modelira UFC evente, borbe, borce, rezultate i statistiku borbe.
Podaci su preuzeti iz Kaggle dataseta `UFC DATASETS 1994-2025`, a prvo se
uvoze u staging tablice jer CSV sadrzi puno denormaliziranih stupaca.

## Sto je koristenje gradiva s predavanja

- SQL ponavljanje: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `JOIN`, `GROUP BY`, `HAVING`, `ORDER BY`.
- Pogledi: `ufc.v_event_results`, `ufc.v_fighter_summary`, `ufc.v_weight_class_statistics`.
- Triggeri: `ufc.trg_Fight_Audit` zapisuje promjene u `audit.ChangeLog`.
- Transakcije: procedure imaju `BEGIN TRANSACTION`, `COMMIT` i `ROLLBACK`.
- Procedure: dohvat borbi, usporedba boraca, paging i promjena rezultata.
- JSON: `FOR JSON PATH`, `ISJSON`, `JSON_VALUE`.

## Sto nije koristenje i zasto

- APEX nije ukljucen jer nije potreban za ovaj projekt i vezan je uz Oracle okruzenje.
- MongoDB/NoSQL nije ukljucen jer je zadatak napraviti relacijsku bazu u SQL Serveru.
- Distribuirane baze nisu ukljucene jer je projekt lokalni studentski sustav i nema stvarnu potrebu za horizontalnim skaliranjem.

## Demo redoslijed u SSMS-u

1. Pokazati tablice u shemama `geo`, `ref`, `ufc`, `audit`.
2. Otvoriti ER dijagram ili `docs/ER_UFC.mmd`.
3. Pokrenuti view `SELECT TOP 20 * FROM ufc.v_event_results`.
4. Pokrenuti CTE/window primjere iz `07_demo_queries.sql`.
5. Pokrenuti rollback demo procedure `sp_import_fight_result_json`.
6. Pokazati da audit trigger radi kod commita i da rollback ponistava promjenu.
