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

## Dodatna tehnička objašnjenja

### Zašto su korištene sheme

Baza je namjerno podijeljena u više SQL Server shema jer se tako jasnije vidi
uloga pojedinih tablica. Shema u SQL Serveru služi kao logički kontejner za
objekte baze podataka. U ovom projektu to pomaže kod čitanja modela, kod obrane
projekta i kod odvajanja tehničkih tablica od stvarnih poslovnih entiteta.

Korištene su sljedeće sheme:

- `stg` - staging sloj za sirove podatke iz Kaggle datoteka.
- `geo` - geografske tablice: države, regije i gradovi.
- `ref` - šifrarnici i referentne tablice.
- `ufc` - glavne domenske tablice UFC projekta.
- `audit` - tehnički zapis promjena koje proizvodi trigger.

Ovakva organizacija nije nužna za malu bazu, ali je dobra praksa jer baza odmah
izgleda urednije. Umjesto da su sve tablice u `dbo`, iz samog naziva objekta se
vidi kojem dijelu sustava pripada. Na primjer, `ufc.Fight` je glavna poslovna
tablica, `ref.VictoryMethod` je šifrarnik, a `audit.ChangeLog` nije dio UFC
domene nego služi za praćenje izmjena.

### Čemu služi `stg` shema

`stg` znači staging. To je privremeni sloj u koji se podaci učitavaju gotovo u
istom obliku u kojem dolaze iz CSV/TSV datoteka. U ovom projektu staging je
važan zato što Kaggle dataset nije normaliziran za relacijsku bazu. U jednoj
datoteci nalaze se podaci o eventu, borcima, rezultatu, metodama pobjede i
statistikama borbe.

Prednosti staging sloja:

- import je jednostavniji jer se prvo izbjegava složena normalizacija;
- lakše je provjeriti broj redaka iz svake datoteke;
- transformacija se može ponovno pokrenuti bez ponovnog skidanja dataseta;
- pogreške iz izvora ne kvare odmah finalne tablice;
- moguće je usporediti sirove i normalizirane podatke.

Kod obrane je dobro naglasiti da staging nije konačni model baze. Staging je
tehnički međukorak, a relacijski model nastaje u `geo`, `ref` i `ufc` shemama.

### Zašto su šifrarnici u `ref`

Shema `ref` sadrži podatke koji se puno puta ponavljaju i koji imaju ulogu
šifrarnika. Primjeri su `WeightClass`, `Stance`, `VictoryMethod`,
`VictoryDetail`, `FightFormat` i `Referee`.

Da nema tih tablica, ista tekstualna vrijednost bi se ponavljala u tisućama
redaka. Na primjer, vrijednost `KO/TKO` ili `Decision - Unanimous` mogla bi biti
zapisana mnogo puta u tablici borbi. Normalizacijom se takve vrijednosti spremaju
jednom, a glavne tablice koriste strani ključ. Time se smanjuje dupliciranje i
olakšava grupiranje podataka u analitičkim upitima.

### Zašto su lokacije izdvojene u `geo`

Eventi se održavaju u gradovima, gradovi pripadaju regijama, a regije državama.
Zato su lokacije izdvojene u tri tablice: `geo.Country`, `geo.Region` i
`geo.City`. Time se modelira prirodna hijerarhija:

```text
Country -> Region -> City -> Event
```

Ova struktura omogućuje jednostavne upite poput:

- svi eventi u Abu Dhabiju;
- broj evenata po državi;
- broj borbi po regiji;
- usporedba aktivnosti UFC-a kroz različite lokacije.

### Zašto je `FightParticipant` potreban

Veza između boraca i borbi je M:N. Jedan borac može nastupiti u mnogo borbi, a
jedna borba ima više sudionika, u pravilu crvenog i plavog borca. Takva veza se
u relacijskom modelu ne zapisuje direktno, nego preko međutablice.

U ovom projektu ta međutablica je `ufc.FightParticipant`. Ona ne služi samo kao
tehnička spojna tablica, nego sadrži i značenje sudjelovanja: kut borca
(`Red`/`Blue`), je li pobjednik, je li borac bio favorit i slične podatke. Zbog
toga je model fleksibilniji i prirodniji od varijante u kojoj bi se u tablici
`Fight` držali samo stupci `red_fighter_id` i `blue_fighter_id`.

### Zašto su statistike izdvojene iz `Fight`

Tablica `ufc.Fight` opisuje samu borbu: event, kategoriju, format, metodu
pobjede, rundu završetka i pobjednika. Detaljne statistike sudionika izdvojene
su u `ufc.FightPerformanceStats` i `ufc.FightStrikeBreakdown`.

Razlog je taj što statistike pripadaju nastupu pojedinog borca u konkretnoj
borbi, a ne borbi kao cjelini. Na primjer, crveni i plavi borac imaju različit
broj značajnih udaraca, pokušaja rušenja i kontrolnog vremena. Zato se
statistike vežu na `fight_participant_id`.

### Zašto postoji `audit.ChangeLog`

`audit.ChangeLog` demonstrira uporabu triggera. Kada se promijeni rezultat borbe
u tablici `ufc.Fight`, trigger zapisuje što se promijenilo, tko je napravio
promjenu i kada se dogodila. Time se pokazuje koncept audit loga, odnosno
povijesti promjena nad važnim podacima.

U stvarnom sustavu audit tablica je korisna jer rezultat borbe nije običan
podatak. Ako se pobjednik, metoda pobjede ili runda završetka naknadno promijene,
dobro je imati trag promjene.

### Zašto se koristi JSON

JSON je uključen zato što SQL Server podržava rad s JSON podacima i zato što se
time pokazuje razmjena podataka između relacijske baze i aplikacijskog sloja.
Projekt koristi dva smjera:

- `FOR JSON PATH` za izvoz fight carda ili rezultata iz baze u JSON format;
- `ISJSON`, `JSON_VALUE` i `OPENJSON` za čitanje JSON ulaza.

To je korisno za modernu aplikaciju jer bi web ili mobilni klijent često tražio
podatke u JSON formatu, iako su oni u bazi pohranjeni relacijski.

### Što demonstriraju viewovi, procedure i transakcije

Viewovi služe za spremanje često korištenih upita pod jednim imenom. Na primjer,
`ufc.v_event_results` spaja evente, borbe, borce, kategorije i metode pobjede u
jedan pregled koji je puno lakše koristiti za demonstraciju i izvještaje.

Procedure služe za spremanje parametarskih operacija. U projektu postoje
procedure za dohvat borbi po eventu, usporedbu dva borca, straničenje rezultata,
promjenu rezultata borbe i JSON izvoz/uvoz.

Transakcija se koristi kod promjene rezultata borbe jer takva promjena mora biti
atomarna. Ako je ulaz neispravan ili se dogodi greška, radi se `ROLLBACK` i baza
ostaje u starom stanju. Ako je sve ispravno, radi se `COMMIT`. Time se pokazuje
ACID ideja iz relacijskih baza: promjena je ili provedena u cijelosti ili nije
provedena uopće.

### Kratko objašnjenje za obranu

Najkraće objašnjenje modela:

```text
stg je ulazni sloj, ref i geo normaliziraju ponavljajuće vrijednosti,
ufc sadrži stvarne poslovne entitete, a audit prati promjene.
```

Najkraće objašnjenje relacija:

```text
Fighter i FighterCareerStats su 1:1, Event i Fight su 1:N, a Fighter i Fight
su M:N preko FightParticipant.
```

Najkraće objašnjenje zašto projekt koristi više objekata s predavanja:

```text
Viewovi pojednostavljuju čitanje podataka, procedure grupiraju poslovnu logiku,
trigger automatski zapisuje promjene, transakcija čuva konzistentnost, a JSON
pokazuje razmjenu podataka prema aplikacijama.
```
