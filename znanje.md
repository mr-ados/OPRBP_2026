# Znanje za obranu: relacijske baze, transakcije, JSON i UFC projekt

Ovaj dokument je skripta za ponavljanje gradiva iz relacijskih baza podataka,
napisana kroz primjere iz projekta `UFC_OPRBP`. Cilj nije učiti definicije
napamet, nego razumjeti što se događa u bazi i znati to objasniti na obrani.

Kratka rečenica za početak obrane:

```text
Projekt je relacijska SQL Server baza nad UFC datasetom. Sirovi Kaggle podaci
prvo se učitavaju u staging sloj, a zatim se normaliziraju u tablice za evente,
borbe, borce, lokacije, šifrarnike, statistike i audit promjena.
```

---

## 1. Što su relacijske baze podataka?

### Definicija

Relacijska baza podataka je baza u kojoj se podaci organiziraju u tablice.
Tablice imaju retke i stupce, a veze između tablica ostvaruju se pomoću
ključeva. Najvažniji pojmovi su:

- **tablica** - skup podataka o jednom tipu entiteta;
- **redak** - jedan konkretan zapis;
- **stupac** - jedno svojstvo zapisa;
- **primarni ključ** - jedinstveno identificira redak;
- **strani ključ** - povezuje redak s retkom u drugoj tablici;
- **SQL** - jezik za definiranje, dohvat i promjenu podataka.

U UFC projektu primjeri tablica su:

- `ufc.Fighter` - borci;
- `ufc.Event` - eventi;
- `ufc.Fight` - borbe;
- `ufc.FightParticipant` - nastup borca u borbi;
- `ref.WeightClass` - kategorije;
- `geo.City` - gradovi.

### Jednostavno objašnjenje

Relacijsku bazu možeš zamišljati kao dobro organiziranu zbirku povezanih
tablica. Umjesto da sve podatke o UFC borbi držiš u jednoj ogromnoj tablici,
razdvajaš ih prema značenju. Event je jedno, borac je drugo, borba je treće,
a statistika nastupa je četvrto.

Zato u projektu ne držiš sve samo u `UFC.csv`, nego imaš više tablica koje su
povezane ključevima.

### Primjer iz projekta

U tablici `ufc.Fight` svaka borba pripada jednom eventu. To je 1:N veza:
jedan event ima više borbi.

```sql
CREATE TABLE ufc.Fight
(
    fight_id VARCHAR(32) CONSTRAINT PK_Fight PRIMARY KEY,
    event_id VARCHAR(32) NOT NULL,
    winner_fighter_id VARCHAR(32) NULL,
    CONSTRAINT FK_Fight_Event
        FOREIGN KEY (event_id) REFERENCES ufc.Event(event_id),
    CONSTRAINT FK_Fight_Winner
        FOREIGN KEY (winner_fighter_id) REFERENCES ufc.Fighter(fighter_id)
);
```

Ovaj isječak pokazuje dvije važne stvari:

- `fight_id` je primarni ključ borbe;
- `event_id` i `winner_fighter_id` su strani ključevi prema drugim tablicama.

### Prednosti relacijskih baza

- **Jasna struktura** - zna se koje tablice postoje i koji stupci pripadaju
  kojoj tablici.
- **Integritet podataka** - primarni ključevi, strani ključevi i `CHECK`
  ograničenja sprječavaju nelogične podatke.
- **SQL je moćan** - lako se pišu upiti s `JOIN`, `GROUP BY`, CTE i window
  funkcijama.
- **Transakcije** - relacijske baze dobro podržavaju `COMMIT`, `ROLLBACK` i
  ACID svojstva.
- **Dobre za izvještaje** - analitika nad povezanim tablicama je prirodna.

### Mane relacijskih baza

- **Shema je stroža** - prije spremanja podataka moraš znati strukturu tablica.
- **Promjene modela mogu biti teže** - dodavanje novih odnosa ili stupaca može
  tražiti migracije.
- **Nisu uvijek idealne za jako promjenjive podatke** - npr. kada svaki zapis
  ima potpuno drugačiji oblik.
- **Horizontalno skaliranje zna biti složenije** - posebno kada se koristi puno
  transakcija i relacija.

### Kako to reći na obrani

```text
Relacijska baza je dobar izbor za UFC projekt jer domena prirodno ima entitete
i veze: event ima borbe, borba ima borce, borac ima statistike, a kategorije i
metode pobjede ponavljaju se kao šifrarnici.
```

---

## 2. Kako se relacijske baze razlikuju od nerelacijskih?

### Definicija nerelacijskih baza

Nerelacijske baze, često zvane NoSQL baze, ne koriste nužno tablice s fiksnom
shemom i relacije preko stranih ključeva. One mogu spremati podatke kao:

- dokumente, npr. JSON dokumente;
- parove ključ-vrijednost;
- grafove;
- široke stupčane obitelji;
- vremenske serije.

Važno: **JSON nije automatski NoSQL baza**. JSON je format zapisa podataka.
SQL Server može raditi s JSON-om, ali i dalje ostaje relacijska baza.

### Razlika na jednostavnom primjeru

U relacijskoj bazi jedan UFC event bi bio u `ufc.Event`, borbe u `ufc.Fight`,
borci u `ufc.Fighter`, a veza borbe i boraca u `ufc.FightParticipant`.

U dokumentnoj NoSQL bazi jedan event bi mogao biti jedan veliki JSON dokument:

```json
{
  "event_name": "UFC 300",
  "location": "Las Vegas, Nevada, USA",
  "fights": [
    {
      "red_fighter": "Fighter A",
      "blue_fighter": "Fighter B",
      "winner": "Fighter A",
      "method": "KO/TKO"
    }
  ]
}
```

To je praktično za dohvat cijelog eventa odjednom, ali je teže održavati ako se
isti borac pojavljuje u mnogo dokumenata.

### Prednosti nerelacijskih baza

- **Fleksibilna struktura** - lakše je spremati podatke različitog oblika.
- **Dobre za velike količine promjenjivih podataka** - osobito kod web i
  mobilnih aplikacija.
- **Često se lakše horizontalno skaliraju** - ovisno o vrsti NoSQL baze.
- **Dokumentne baze su prirodne za JSON API-je** - jedan dokument može biti
  gotovo isti kao odgovor aplikacijskog API-ja.

### Mane nerelacijskih baza

- **Slabija relacijska kontrola** - često nema stranih ključeva kao u SQL-u.
- **Redundancija je češća** - isti podatak se često ponavlja u više dokumenata.
- **Složeni JOIN upiti nisu prirodni** - neke NoSQL baze ih nemaju ili ih imaju
  ograničeno.
- **Konzistentnost može biti kompromis** - neke NoSQL baze daju prednost
  dostupnosti i skaliranju.

### Primjer iz UFC projekta

Tvoj projekt koristi JSON, ali nije NoSQL projekt. Ovo je relacijski projekt jer
su glavni podaci u tablicama, a JSON se koristi za izvoz i uvoz podataka:

```sql
EXEC ufc.sp_get_event_card_json @event_id = @LatestEventId;
```

To znači:

```text
Model je relacijski, ali JSON koristim kao format razmjene podataka.
```

---

## 3. Big Data 4V: volume, variety, velocity, veracity

Big Data se često opisuje kroz 4V svojstva: volume, variety, velocity i
veracity.

### Volume - količina podataka

`Volume` znači da ima jako puno podataka. To mogu biti milijuni ili milijarde
redaka, velike količine slika, logova, senzorskih podataka ili transakcija.

U UFC projektu podataka nema na razini pravog Big Data sustava, ali se vidi
princip: dataset ima tisuće borbi i puno stupaca. Zato je korisno imati
strukturiran model, staging sloj i upite koji mogu agregirati podatke.

Primjer agregacije:

```sql
SELECT
    event_year = YEAR(e.event_date),
    event_count = COUNT(DISTINCT e.event_id),
    fight_count = COUNT(f.fight_id)
FROM ufc.Event e
INNER JOIN ufc.Fight f ON f.event_id = e.event_id
GROUP BY YEAR(e.event_date)
ORDER BY event_year;
```

### Variety - raznolikost podataka

`Variety` znači da podaci dolaze u različitim oblicima. Neki su strukturirani,
neki polustrukturirani, a neki nestrukturirani.

Primjeri:

- strukturirani podaci: SQL tablice;
- polustrukturirani podaci: JSON, XML, CSV;
- nestrukturirani podaci: slike, video, slobodan tekst.

U tvom projektu CSV/TSV podaci dolaze kao polustrukturirani ulaz, a zatim se
pretvaraju u strukturirane SQL tablice.

### Velocity - brzina dolaska podataka

`Velocity` znači koliko brzo podaci nastaju i dolaze u sustav.

Primjer: aplikacija koja svake sekunde prima tisuće logova, klikova ili
transakcija ima velik velocity.

U UFC projektu podaci nisu real-time. Dataset se učitava kao batch import.
Zato nije trebalo raditi stream processing, nego je dovoljno:

```text
CSV/TSV -> staging tablice -> transformacija -> normalizirani model
```

### Veracity - pouzdanost podataka

`Veracity` znači koliko su podaci točni, potpuni i pouzdani.

U stvarnim datasetima često postoje:

- prazne vrijednosti;
- krivo napisani nazivi;
- različiti formati datuma;
- ekstremne vrijednosti;
- duplicirani podaci.

U UFC projektu se to vidjelo kod težine borca. Constraint je prvo bio previše
strog, a dataset je imao povijesni open-weight slučaj:

```sql
CONSTRAINT CK_Fighter_weight
CHECK (weight_kg IS NULL OR weight_kg BETWEEN 35 AND 400)
```

Ovo je dobar primjer `veracity` problema: baza mora imati pravila, ali pravila
moraju odgovarati stvarnim podacima.

---

## 4. Kako se podaci pohranjuju u relacijskim bazama?

### Definicija

U relacijskim bazama podaci se logički pohranjuju u tablice. Fizički, SQL Server
sprema podatke u podatkovne datoteke i organizira ih u stranice, ekstenzije i
indekse. Za obranu obično nije potrebno ići jako duboko u fizičku arhitekturu,
ali je važno razumjeti logički dio.

Logički model:

```text
baza -> sheme -> tablice -> stupci i retci -> ključevi i ograničenja
```

U projektu:

```text
UFC_OPRBP
  stg.EventDetails
  geo.Country
  ref.WeightClass
  ufc.Event
  ufc.Fight
  audit.ChangeLog
```

### Kako to izgleda u UFC projektu

Event je spremljen u `ufc.Event`, a lokacija eventa povezana je s gradom:

```sql
CREATE TABLE ufc.Event
(
    event_id VARCHAR(32) CONSTRAINT PK_Event PRIMARY KEY,
    event_name NVARCHAR(300) NOT NULL,
    event_date DATE NULL,
    city_id INT NULL,
    location_raw NVARCHAR(300) NULL,
    CONSTRAINT FK_Event_City
        FOREIGN KEY (city_id) REFERENCES geo.City(city_id)
);
```

Ovdje se vidi:

- `event_id` je identitet eventa;
- `city_id` povezuje event s lokacijom;
- `location_raw` ostaje sirovi tekst lokacije iz dataseta.

### Kako se to razlikuje od nerelacijskih baza?

U nerelacijskoj dokumentnoj bazi event bi mogao biti jedan dokument koji u sebi
ima i lokaciju i borbe i borce. U relacijskoj bazi to se razdvaja u tablice.

Relacijski pristup:

```text
Event -> Fight -> FightParticipant -> Fighter
```

Dokumentni pristup:

```text
Event dokument s ugniježđenim arrayem borbi i boraca
```

Relacijski pristup je bolji kada se isti podaci često ponavljaju i kada treba
održavati veze. Dokumentni pristup je bolji kada često dohvaćaš cijeli dokument
odjednom i kada struktura može varirati.

---

## 5. Normalizacija

### Definicija

Normalizacija je postupak organiziranja podataka u relacijskoj bazi tako da se
smanji redundancija i spriječe anomalije pri unosu, izmjeni i brisanju podataka.

Pojednostavljeno, može se reći da je normalizacija “razbijanje velikih tablica
na manje”, ali to nije cijela definicija. Preciznije:

```text
Normalizacija znači razdvajanje podataka prema ovisnostima i značenju, tako da
svaka tablica opisuje jednu stvar i da se isti podatak nepotrebno ne ponavlja.
```

### Zašto normaliziramo?

Bez normalizacije nastaju anomalije:

- **insert anomalija** - ne možeš unijeti podatak bez nekog drugog podatka;
- **update anomalija** - isti podatak moraš mijenjati na više mjesta;
- **delete anomalija** - brisanjem jednog zapisa slučajno izgubiš drugi važan
  podatak.

Primjer: ako se ime kategorije `lightweight` ponavlja u svakoj borbi, promjena
naziva ili ispravak tipfelera mora se napraviti u puno redaka. Zato postoji
`ref.WeightClass`.

```sql
CREATE TABLE ref.WeightClass
(
    weight_class_id INT IDENTITY(1,1) CONSTRAINT PK_WeightClass PRIMARY KEY,
    division_name NVARCHAR(120) NOT NULL
        CONSTRAINT UQ_WeightClass_division UNIQUE
);
```

### 1NF - prva normalna forma

Tablica je u 1NF ako:

- svaki stupac ima atomske vrijednosti;
- nema ponavljajućih grupa u istom retku;
- svaki redak se može jedinstveno identificirati.

Loš primjer:

```text
Fight(fight_id, red_fighter, blue_fighter, red_stats, blue_stats)
```

To je problem jer isti redak sadrži dvije uloge boraca i ponavljajuće skupine
stupaca.

U projektu je to popravljeno s `ufc.FightParticipant`:

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

### 2NF - druga normalna forma

2NF traži da je tablica u 1NF i da svaki neključni atribut ovisi o cijelom
primarnom ključu, a ne samo o dijelu složenog ključa.

To je važno kod tablica sa složenim ključem. `ufc.FightParticipant` ima ključ:

```text
(fight_id, corner_color)
```

Podaci kao `fighter_id`, `is_winner` i `result_label` ovise o nastupu borca u
konkretnoj borbi i kutu. Zato su prikladni za tu tablicu.

Ali podaci poput `fighter_name` ne bi trebali biti u `FightParticipant`, jer ime
borca ovisi o `fighter_id`, a ne o cijelom ključu `(fight_id, corner_color)`.
Zato je ime u `ufc.Fighter`.

### 3NF - treća normalna forma

3NF traži da neključni atributi ne ovise o drugim neključnim atributima. Drugim
riječima, tablica ne smije skrivati dodatne ovisnosti koje treba razdvojiti.

Primjer: ako bi u `ufc.Event` stajalo:

```text
event_id, city_name, region_name, country_name
```

tada `country_name` ovisi o `region_name` ili lokacijskoj hijerarhiji, a ne
izravno samo o eventu. Zato je lokacija razdvojena:

```text
geo.Country -> geo.Region -> geo.City -> ufc.Event
```

### BCNF

BCNF je stroža verzija 3NF. Ideja je da svaka determinanta mora biti kandidat
ključ. Za studentski projekt je dovoljno znati da BCNF dodatno smanjuje
nepravilne ovisnosti, ali može povećati broj tablica i složenost modela.

### Kako prepoznati koju normalnu formu treba popraviti?

Možeš si postaviti pitanja:

1. Ima li stupac više vrijednosti u jednoj ćeliji?
   - Ako da, problem je 1NF.
2. Ima li tablica složeni ključ i neki atribut ovisi samo o dijelu ključa?
   - Ako da, problem je 2NF.
3. Ovisi li neki neključni atribut o drugom neključnom atributu?
   - Ako da, problem je 3NF.
4. Postoje li više različitih kandidata za ključ i neobične funkcijske
   ovisnosti?
   - Možda treba BCNF.

### Ima li redundantnosti u tvojoj bazi?

Glavni model je uglavnom normaliziran. Redundancija postoji namjerno na nekoliko
mjesta:

- `stg` tablice su sirove i denormalizirane jer služe za import;
- `ufc.Event.location_raw` čuva originalnu tekstualnu lokaciju iz dataseta;
- viewovi poput `ufc.v_event_results` prikazuju spojene podatke, ali ih ne
  pohranjuju kao novu fizičku kopiju.

To nije problem, nego svjesna odluka. Staging sloj se ne smatra finalnim
relacijskim modelom.

### Bi li se još nešto moglo razdvojiti?

Moglo bi se dodatno razdvajati, ali nije nužno za ovaj projekt. Primjeri:

- `FightStrikeBreakdown` bi se mogao pretvoriti u tablicu po tipu mete
  (`Head`, `Body`, `Leg`) i pozicije (`Distance`, `Clinch`, `Ground`);
- `location_raw` bi se mogao potpuno ukloniti nakon normalizacije lokacija;
- `VictoryDetail` bi se mogla još strože modelirati ako bi dataset imao
  kompleksniju hijerarhiju metoda.

Za studentski projekt trenutni model je dobar kompromis između normalizacije i
čitljivosti. Previše tablica bi otežalo obranu bez velike koristi.

---

## 6. Denormalizacija

### Definicija

Denormalizacija je namjerno uvođenje redundancije ili spajanje podataka koji su
inače normalizirani, najčešće radi bržeg čitanja, jednostavnijih izvještaja ili
lakšeg rada aplikacije.

### Jednostavno objašnjenje

Normalizacija kaže: razdvoji podatke da se ne ponavljaju.

Denormalizacija kaže: ponekad je praktično ponovno spojiti dio podataka, ako to
ubrzava čitanje ili pojednostavljuje izvještaj.

### Možemo li baratati denormaliziranim podacima u bazi?

Da. Denormalizirani podaci nisu zabranjeni. Važno je znati zašto postoje.

U tvom projektu staging tablice su denormalizirane:

```text
stg.UFCMaster
```

U toj tablici se nalaze podaci o eventu, borbi, crvenom borcu, plavom borcu,
statistikama i rezultatu. To je dobro za import, ali nije dobro kao finalni
model.

### Primjer denormaliziranog čitanja preko viewa

`ufc.v_event_results` je praktičan jer spaja više tablica u jedan pregled:

```sql
SELECT TOP (20)
    event_date,
    event_name,
    division_name,
    red_fighter,
    blue_fighter,
    winner,
    method
FROM ufc.v_event_results
ORDER BY event_date DESC;
```

Ovo je denormalizirani prikaz za čitanje, ali podaci i dalje fizički ostaju u
normaliziranim tablicama.

### Prednosti denormalizacije

- brže čitanje u nekim slučajevima;
- jednostavniji izvještaji;
- manje `JOIN` operacija u aplikaciji;
- praktično za staging i analitičke slojeve.

### Mane denormalizacije

- veća redundancija;
- veći rizik nekonzistentnosti;
- složenije izmjene jer se isti podatak može pojaviti na više mjesta;
- treba paziti što je “izvor istine”.

### Kako to reći na obrani

```text
Koristio sam denormalizirane podatke u staging sloju jer su takvi došli iz
dataseta. Finalni model sam normalizirao, a viewove koristim kao čitljive
denormalizirane prikaze za izvještaje.
```

---

## 7. Transakcije

### Definicija

Transakcija je skup jedne ili više SQL naredbi koje se izvršavaju kao jedna
logička cjelina. Transakcija se ili potvrdi s `COMMIT`, ili poništi s
`ROLLBACK`.

Osnovni oblik:

```sql
BEGIN TRANSACTION;
    -- SQL naredbe
COMMIT TRANSACTION;
```

Ako nešto pođe krivo:

```sql
BEGIN TRANSACTION;
    -- SQL naredbe
ROLLBACK TRANSACTION;
```

### Jednostavno objašnjenje

Transakcija je kao “probaj napraviti sve, ali ako ne možeš sve, vrati sve na
početak”.

U UFC projektu to je važno kod promjene rezultata borbe. Ne želiš promijeniti
pobjednika u `ufc.Fight`, a zaboraviti promijeniti `is_winner` i `result_label`
u `ufc.FightParticipant`.

### Primjer iz projekta

U proceduri `ufc.sp_update_fight_result` koristiš transakciju:

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

Ovo pokazuje:

- transakcija počinje s `BEGIN TRANSACTION`;
- radi se više povezanih izmjena;
- ako je `@commit_changes = 1`, promjena ostaje;
- ako nije, radi se rollback;
- ako se dogodi greška, `CATCH` blok vraća stanje.

### Prednosti transakcija

- čuvaju konzistentnost baze;
- omogućuju siguran rollback;
- više naredbi se ponaša kao jedna cjelina;
- važne su za sustave gdje se podaci često mijenjaju.

### Mane transakcija

- duge transakcije mogu zaključavati podatke;
- mogu usporiti druge korisnike;
- mogu povećati transaction log;
- kod distribuiranih sustava postaju složenije.

---

## 8. ACID svojstva

ACID opisuje četiri svojstva transakcija:

```text
A - Atomicity
C - Consistency
I - Isolation
D - Durability
```

### A - Atomicity

Atomicity znači da je transakcija nedjeljiva. Ili se izvrši cijela ili se ne
izvrši ništa.

Primjer iz UFC projekta:

```text
Ako mijenjam rezultat borbe, želim promijeniti i ufc.Fight i
ufc.FightParticipant. Ako druga promjena padne, prva se mora poništiti.
```

Zato se koristi `ROLLBACK`.

### C - Consistency

Consistency znači da transakcija mora bazu prevesti iz jednog ispravnog stanja u
drugo ispravno stanje.

Primjer:

- `winner_fighter_id` mora pokazivati na postojećeg borca;
- pobjednik mora biti sudionik te borbe;
- `significant_strikes_landed` ne smije biti veći od
  `significant_strikes_attempted`.

Constraint iz projekta:

```sql
CONSTRAINT CK_FightPerformance_sig
CHECK
(
    significant_strikes_landed IS NULL
    OR significant_strikes_attempted IS NULL
    OR significant_strikes_landed <= significant_strikes_attempted
)
```

### I - Isolation

Isolation znači da istovremene transakcije ne smiju jedna drugoj proizvoditi
nelogične rezultate. Drugim riječima, ako više korisnika radi s bazom u isto
vrijeme, svaki korisnik treba vidjeti konzistentno stanje prema odabranoj razini
izolacije.

Tu dolaze pojmovi poput:

- dirty read;
- non-repeatable read;
- phantom read;
- lockovi;
- isolation level.

### D - Durability

Durability znači da potvrđena transakcija ostaje zapisana čak i ako nakon toga
dođe do pada sustava.

Ako SQL Server kaže da je `COMMIT` uspješan, promjena mora preživjeti restart,
pad procesa ili nestanak struje. Zato postoji transaction log.

### Kako to reći na obrani

```text
ACID znači da je transakcija nedjeljiva, da čuva pravila baze, da je izolirana
od drugih transakcija i da potvrđena promjena ostaje trajno zapisana.
```

---

## 9. Dirty read i razine izolacije

### Što je dirty read?

Dirty read se dogodi kada jedna transakcija pročita podatak koji je druga
transakcija promijenila, ali još nije commitirala.

Problem je u tome što se ta druga transakcija može rollbackati. Tada je prva
transakcija pročitala podatak koji zapravo nikad nije službeno postojao.

### Jednostavan primjer

Transakcija A:

```sql
BEGIN TRANSACTION;

UPDATE ufc.Fight
SET match_time_sec = 10
WHERE fight_id = 'demo_fight';

-- još nema COMMIT
```

Transakcija B, ako koristi `READ UNCOMMITTED`, može pročitati:

```sql
SELECT match_time_sec
FROM ufc.Fight
WHERE fight_id = 'demo_fight';
```

Ako Transakcija A zatim napravi:

```sql
ROLLBACK TRANSACTION;
```

Transakcija B je pročitala nečistu vrijednost. To je dirty read.

### Zašto je to loše?

Kod UFC projekta bi to značilo da netko može pročitati privremeno promijenjeni
rezultat borbe koji kasnije bude poništen. To bi bilo pogrešno za izvještaj ili
aplikaciju.

### Izolacijske razine ukratko

- `READ UNCOMMITTED` - dopušta dirty read.
- `READ COMMITTED` - ne dopušta dirty read; čita samo commitane podatke.
- `REPEATABLE READ` - sprječava da se pročitani redak promijeni dok traje
  transakcija.
- `SERIALIZABLE` - najstrože, sprječava i phantom retke.
- `SNAPSHOT` - koristi verzije redaka, pa čitanje ne mora blokirati pisanje na
  isti način.

Za obranu je najvažnije znati:

```text
Dirty read je čitanje necommitane promjene. Ako se ta promjena rollbacka,
pročitani podatak više ne vrijedi.
```

---

## 10. Lockovi: shared, exclusive i intent

### Što su lockovi?

Lockovi su mehanizam kojim baza kontrolira istovremeni pristup podacima. Kada
jedna transakcija čita ili mijenja podatke, SQL Server može zaključati redak,
stranicu ili tablicu kako bi spriječio konflikt s drugim transakcijama.

### Shared lock

Shared lock se koristi kod čitanja. Više transakcija može imati shared lock nad
istim podatkom jer više čitanja ne smeta jedno drugome.

Jednostavno:

```text
Ja čitam, ti čitaš, to je u redu.
```

Problem nastaje ako netko želi pisati dok drugi čita, ovisno o razini izolacije.

### Exclusive lock

Exclusive lock se koristi kod izmjene podataka: `INSERT`, `UPDATE`, `DELETE`.
Dok jedna transakcija ima exclusive lock, druge transakcije ne mogu mijenjati
isti podatak.

Jednostavno:

```text
Ja mijenjam ovaj redak, nitko drugi ga ne smije mijenjati dok ne završim.
```

Primjer iz projekta:

```sql
UPDATE ufc.Fight
SET winner_fighter_id = @winner_fighter_id
WHERE fight_id = @fight_id;
```

Ova naredba može uzeti exclusive lock nad retkom borbe koju mijenja.

### Intent lock

Intent lock je “najava” da transakcija namjerava zaključati nešto na nižoj
razini. Na primjer, ako SQL Server zaključa jedan redak, može postaviti intent
lock na tablicu kako bi drugi procesi znali da unutar te tablice postoje
zaključani dijelovi.

Jednostavno:

```text
Na razini tablice stoji oznaka: pazi, netko unutra već ima lock na neke retke.
```

Intent lockovi pomažu SQL Serveru da brže provjerava kompatibilnost lockova i
da ne mora stalno pregledavati svaki pojedinačni redak.

### Prednosti lockova

- sprječavaju konfliktne izmjene;
- čuvaju izolaciju;
- pomažu da transakcije vide konzistentne podatke.

### Mane lockova

- mogu blokirati druge korisnike;
- duge transakcije mogu stvoriti čekanja;
- može nastati deadlock ako dvije transakcije čekaju jedna drugu.

### Kako to reći na obrani

```text
Shared lock služi za čitanje, exclusive lock za pisanje, a intent lock označava
da unutar većeg objekta postoje lockovi na nižoj razini.
```

---

## 11. Transaction log, write-ahead logging i `fn_dblog`

### Što je transaction log?

Transaction log je dnevnik promjena u SQL Server bazi. Prije nego što se promjena
smatra trajnom, SQL Server zapisuje informacije o toj promjeni u log.

Log služi za:

- rollback neuspješnih transakcija;
- recovery nakon pada sustava;
- osiguravanje durability svojstva;
- backup i restore scenarije.

### Zašto se log mora zapisati prije prihvaćanja transakcije?

SQL Server koristi princip **write-ahead logging**. To znači:

```text
Opis promjene mora biti zapisan u log prije nego što se sama promjena smatra
potvrđenom.
```

Razlog je sigurnost. Ako se dogodi pad sustava odmah nakon `COMMIT`, SQL Server
mora moći iz loga rekonstruirati što je bilo potvrđeno.

Ako log nije uspješno zapisan, baza ne može garantirati durability. Zato se
`COMMIT` ne smije smatrati uspješnim dok log zapis nije siguran.

### Kako rollback koristi log?

Ako transakcija napravi izmjenu i zatim se rollbacka, SQL Server koristi log da
zna koje promjene treba poništiti.

U UFC projektu:

```sql
EXEC ufc.sp_import_fight_result_json
    @payload = @Payload,
    @commit_changes = 0;
```

Ovdje procedura poziva transakciju koja napravi promjene kao demo, ali ih zatim
poništi. Log omogućuje da se baza vrati na prethodno stanje.

### Što je `fn_dblog`?

`fn_dblog` je nedokumentirana SQL Server funkcija kojom se može čitati sadržaj
transaction loga. Korisna je za učenje i istraživanje jer pokazuje da se
promjene stvarno zapisuju u log.

Primjer oblika:

```sql
SELECT TOP (50) *
FROM fn_dblog(NULL, NULL);
```

Važno:

- `fn_dblog` nije standardni alat za aplikacijski kod;
- nije preporučljivo oslanjati se na nju u produkciji;
- koristi se oprezno, najviše za edukaciju, analizu i administraciju.

### Kako to reći na obrani

```text
Transaction log je potreban zato što baza mora znati poništiti neuspjele
transakcije i obnoviti potvrđene promjene nakon pada sustava. Write-ahead
logging znači da se log mora zapisati prije nego što se transakcija smatra
potvrđenom.
```

---

## 12. Distribuirani sustavi i distribuirane transakcije

### Što znači distribuirano?

Distribuirano znači da se sustav sastoji od više računala, servisa ili baza koje
rade zajedno. Korisniku može izgledati kao jedan sustav, ali podaci i obrada su
raspoređeni na više mjesta.

Primjeri distribuiranih sustava:

- aplikacija s više mikroservisa;
- baza replicirana na više servera;
- sustav s odvojenim bazama za narudžbe, plaćanja i korisnike;
- cloud sustav koji radi u više regija.

### Što je distribuirana transakcija?

Distribuirana transakcija je transakcija koja uključuje više od jednog resursa,
na primjer dvije baze ili bazu i vanjski sustav.

Primjer:

```text
Jedna transakcija mora istovremeno upisati podatak u SQL Server bazu i u drugu
bazu na drugom serveru.
```

Ako jedna strana uspije, a druga ne, nastaje problem. Zato distribuirane
transakcije koriste koordinacijske mehanizme, npr. two-phase commit.

### Two-phase commit ukratko

1. **Prepare faza** - koordinator pita sve sudionike jesu li spremni za commit.
2. **Commit faza** - ako su svi spremni, koordinator šalje commit; ako netko
   nije spreman, šalje rollback.

### Prednosti distribuiranih transakcija

- osiguravaju konzistentnost kroz više sustava;
- korisne su kad se jedna poslovna operacija mora potvrditi na više mjesta.

### Mane distribuiranih transakcija

- složene su;
- mogu biti spore;
- teže ih je debugirati;
- ovise o mreži;
- mogu stvoriti blokiranja u više sustava.

### Veza s tvojim projektom

Tvoj UFC projekt nije distribuiran. Radi se o lokalnoj SQL Server bazi u SSMS-u.
Zato distribuirane transakcije nisu potrebne.

Kako to reći na obrani:

```text
Distribuirane transakcije nisam koristio jer projekt nema više baza ni više
servera. Dovoljna je lokalna SQL Server transakcija.
```

---

## 13. View

### Definicija

View, odnosno pogled, je spremljeni SQL upit koji se ponaša kao virtualna
tablica. View ne mora fizički spremati podatke; najčešće samo sprema definiciju
upita.

### Jednostavno objašnjenje

View je kao “imenovani SELECT”. Umjesto da svaki put pišeš dugi `JOIN`, spremiš
ga kao view i onda čitaš iz njega.

### Primjer iz projekta

`ufc.v_event_results` spaja evente, borbe, lokacije, kategorije, borce, metode
pobjede i suce:

```sql
CREATE VIEW ufc.v_event_results
AS
SELECT
    e.event_name,
    e.event_date,
    f.fight_id,
    wc.division_name,
    red_f.fighter_name AS red_fighter,
    blue_f.fighter_name AS blue_fighter,
    win_f.fighter_name AS winner,
    vm.method_name AS method
FROM ufc.Fight f
INNER JOIN ufc.Event e ON e.event_id = f.event_id
LEFT JOIN ref.WeightClass wc ON wc.weight_class_id = f.weight_class_id
LEFT JOIN ref.VictoryMethod vm ON vm.victory_method_id = f.victory_method_id
LEFT JOIN ufc.Fighter win_f ON win_f.fighter_id = f.winner_fighter_id;
```

U stvarnoj skripti view ima još JOIN-ova za crvenog i plavog borca, lokacije,
detalje pobjede i suca.

### Prednosti viewova

- pojednostavljuju složene upite;
- skrivaju kompleksne `JOIN` operacije;
- korisni su za izvještaje;
- mogu ograničiti što korisnik vidi;
- čine demo u SSMS-u čitljivijim.

### Mane viewova

- ne ubrzavaju automatski upit ako nisu materijalizirani/indexed;
- mogu sakriti složenost pa korisnik ne vidi koliko je query skup;
- view nad viewom može postati težak za održavanje;
- izmjena podataka kroz view nije uvijek jednostavna.

### Materijalizirani pogled / indexed view

Materijalizirani pogled je pogled čiji se rezultat fizički sprema. U SQL Serveru
sličan koncept je **indexed view**. To znači da se na viewu napravi indeks, pa
se podaci viewa fizički održavaju.

Prednost:

- brže čitanje za neke agregacije i izvještaje.

Mana:

- sporiji `INSERT`, `UPDATE`, `DELETE` jer SQL Server mora održavati i indeks
  viewa;
- više zauzetog prostora;
- stroža pravila za definiciju viewa.

U tvom projektu nisu korišteni indexed viewovi jer nije bilo potrebe. Obični
viewovi su dovoljni za demonstraciju i izvještaje.

---

## 14. Control of flow u T-SQL-u

### Definicija

Control of flow su naredbe koje upravljaju tijekom izvršavanja T-SQL koda.
Umjesto da se sve izvršava linearno, možeš koristiti uvjete, petlje i blokove za
obradu grešaka.

Najčešće naredbe:

- `IF...ELSE`;
- `BEGIN...END`;
- `WHILE`;
- `TRY...CATCH`;
- `THROW`;
- `RETURN`;
- `BREAK` i `CONTINUE`.

### Primjer iz projekta

U proceduri `ufc.sp_update_fight_result` koristi se `IF`, `BEGIN...END`,
`TRY...CATCH` i `THROW`:

```sql
IF NOT EXISTS (SELECT 1 FROM ufc.Fight WHERE fight_id = @fight_id)
    THROW 51000, 'Fight does not exist.', 1;

IF @commit_changes = 1
BEGIN
    COMMIT TRANSACTION;
END
ELSE
BEGIN
    ROLLBACK TRANSACTION;
END;
```

### Zašto je to korisno?

Control of flow omogućuje da procedura donosi odluke:

- postoji li borba;
- je li pobjednik sudionik borbe;
- treba li napraviti commit ili rollback;
- treba li baciti grešku.

### Prednosti

- omogućuje poslovnu logiku u bazi;
- olakšava validaciju;
- pomaže kod kontroliranog rollbacka;
- procedure postaju fleksibilnije.

### Mane

- previše logike u bazi može otežati održavanje;
- proceduralni kod može postati složen;
- treba paziti da baza ne preuzme svu logiku aplikacije.

---

## 15. Triggeri

### Definicija

Trigger je posebna vrsta procedure koja se automatski izvršava kada se dogodi
određeni događaj nad tablicom, na primjer `INSERT`, `UPDATE` ili `DELETE`.

### Jednostavno objašnjenje

Trigger je automatska reakcija baze. Ne pozivaš ga ručno. Ako se promijeni
tablica nad kojom je definiran, SQL Server ga sam pokrene.

### Primjer iz projekta

U projektu postoji trigger:

```text
ufc.trg_Fight_Audit
```

On zapisuje promjene nad tablicom `ufc.Fight` u `audit.ChangeLog`.

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

U SQL Server triggeru postoje logičke tablice:

- `inserted` - novi redci nakon `INSERT` ili `UPDATE`;
- `deleted` - stari redci nakon `DELETE` ili `UPDATE`.

Kod `UPDATE` postoje obje: staro stanje u `deleted`, novo stanje u `inserted`.

### Prednosti triggera

- automatski audit promjena;
- poslovno pravilo se izvršava bez obzira tko mijenja podatke;
- korisno za logiranje, validaciju i sinkronizaciju;
- ne treba ručno pozivati dodatni kod.

### Mane triggera

- mogu sakriti logiku jer se izvršavaju “u pozadini”;
- mogu usporiti izmjene;
- teško ih je debugirati ako ih ima puno;
- loše napisani triggeri mogu stvoriti neočekivane efekte.

### Kako to reći na obrani

```text
Trigger koristim za audit promjena rezultata borbe. Kada se ufc.Fight promijeni,
trigger automatski sprema staro i novo stanje u audit.ChangeLog u JSON obliku.
```

---

## 16. Pohranjene procedure

### Definicija

Pohranjena procedura je spremljeni T-SQL program u bazi podataka. Može primati
parametre, izvršavati upite, raditi validacije, koristiti transakcije i vraćati
rezultate.

### Jednostavno objašnjenje

Procedura je kao funkcija spremljena u bazi. Umjesto da aplikacija svaki put
šalje dugi SQL kod, pozove proceduru.

### Primjeri iz projekta

U projektu postoje procedure:

- `ufc.sp_get_event_fights`;
- `ufc.sp_compare_fighters`;
- `ufc.sp_fights_paging`;
- `ufc.sp_update_fight_result`;
- `ufc.sp_get_event_card_json`;
- `ufc.sp_import_fight_result_json`.

Primjer procedure za dohvat borbi po eventu:

```sql
CREATE PROCEDURE ufc.sp_get_event_fights
    @event_id VARCHAR(32) = NULL,
    @event_name_search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM ufc.v_event_results
    WHERE (@event_id IS NULL OR event_id = @event_id)
      AND (@event_name_search IS NULL OR event_name LIKE N'%' + @event_name_search + N'%')
    ORDER BY event_date DESC, is_title_fight DESC, division_name;
END;
```

### Prednosti procedura

- smanjuju ponavljanje SQL koda;
- mogu sadržavati validaciju;
- mogu koristiti transakcije;
- korisne su za sigurnost jer korisniku možeš dati pravo na proceduru, a ne na
  sve tablice;
- olakšavaju standardizirane operacije.

### Mane procedura

- previše logike u procedurama može otežati aplikaciju;
- mogu biti teže za verzioniranje nego aplikacijski kod;
- treba paziti na parametre i performanse;
- loše napisane procedure mogu biti spore.

### Kako to reći na obrani

```text
Procedure sam koristio za ponavljajuće operacije: dohvat borbi, usporedbu
boraca, paging, transakcijsku promjenu rezultata i rad s JSON-om.
```

---

## 17. JSON u SQL Serveru

### Što je JSON?

JSON, odnosno JavaScript Object Notation, je tekstualni format za zapis
strukturiranih podataka. Često se koristi u web aplikacijama i API-jima.

Primjer:

```json
{
  "fight_id": "123",
  "winner_fighter_id": "456",
  "method_name": "Decision",
  "detail_name": "Unanimous"
}
```

### JSON format nije isto što i NoSQL baza

Ovo je važno:

```text
JSON je format podataka. NoSQL dokumentna baza je sustav koji često koristi JSON
ili slične dokumente kao način pohrane.
```

SQL Server može spremati i obrađivati JSON, ali SQL Server zbog toga ne postaje
NoSQL baza. U tvom projektu podaci su relacijski, a JSON se koristi za:

- izvoz podataka prema aplikaciji;
- uvoz payload podataka;
- audit starog i novog stanja u triggeru.

### Kako SQL Server sprema JSON?

SQL Server JSON najčešće sprema kao tekst, npr. `NVARCHAR(MAX)`. To znači da JSON
nije zasebna relacijska struktura sam po sebi, nego tekst koji SQL Server može
provjeravati i čitati pomoću JSON funkcija.

U `audit.ChangeLog`:

```sql
old_values NVARCHAR(MAX) NULL,
new_values NVARCHAR(MAX) NULL,
CONSTRAINT CK_ChangeLog_old_json
    CHECK (old_values IS NULL OR ISJSON(old_values) = 1),
CONSTRAINT CK_ChangeLog_new_json
    CHECK (new_values IS NULL OR ISJSON(new_values) = 1)
```

Ovo znači:

- `old_values` i `new_values` su tekstualni stupci;
- `ISJSON` provjerava je li tekst valjan JSON;
- trigger sprema staro i novo stanje retka u JSON obliku.

### `FOR JSON PATH`

`FOR JSON PATH` pretvara rezultat SQL upita u JSON.

U projektu se koristi u `ufc.sp_get_event_card_json`:

```sql
SELECT
    e.event_id,
    e.event_name,
    e.event_date,
    e.location_raw,
    fights =
    (
        SELECT
            vr.fight_id,
            vr.division_name,
            vr.red_fighter,
            vr.blue_fighter,
            vr.winner,
            vr.method
        FROM ufc.v_event_results vr
        WHERE vr.event_id = e.event_id
        FOR JSON PATH
    )
FROM ufc.Event e
WHERE e.event_id = @event_id
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
```

Ovo vraća jedan event i u njemu listu borbi kao JSON array.

### `ISJSON`

`ISJSON` provjerava je li tekst ispravan JSON.

Primjer iz procedure:

```sql
IF ISJSON(@payload) <> 1
    THROW 52000, 'Payload must be valid JSON.', 1;
```

To je validacija prije nego što procedura pokuša čitati JSON.

### `JSON_VALUE`

`JSON_VALUE` čita jednu skalarnu vrijednost iz JSON-a.

Primjer:

```sql
DECLARE @fight_id VARCHAR(32) =
    JSON_VALUE(@payload, '$.fight_id');

DECLARE @winner_fighter_id VARCHAR(32) =
    JSON_VALUE(@payload, '$.winner_fighter_id');
```

Ovo čita vrijednosti iz JSON payload-a.

### `OPENJSON`

`OPENJSON` pretvara JSON array ili objekt u tablični rezultat. U tvom projektu
glavni primjer uvoza koristi `JSON_VALUE`, ali `OPENJSON` bi bio koristan kada
bi payload imao listu borbi ili listu sudionika.

Primjer kako bi izgledalo:

```sql
DECLARE @json NVARCHAR(MAX) = N'
[
  { "fighter_id": "1", "corner": "Red" },
  { "fighter_id": "2", "corner": "Blue" }
]';

SELECT fighter_id, corner
FROM OPENJSON(@json)
WITH
(
    fighter_id VARCHAR(32) '$.fighter_id',
    corner VARCHAR(8) '$.corner'
);
```

### JSON payload iz `07_demo_queries.sql`

U demo skripti kreira se JSON payload koji uključuje ID borbe, labelu borbe,
ID pobjednika i ime pobjednika:

```sql
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
```

Ovo je dobar primjer za obranu jer pokazuje:

- stvaranje JSON-a u SQL Serveru;
- provjeru valjanosti JSON-a;
- čitanje vrijednosti iz JSON-a;
- povezivanje JSON-a s transakcijskom procedurom.

### Prednosti JSON-a u SQL Serveru

- praktičan je za API-je i aplikacije;
- omogućuje izvoz složenih rezultata kao jedan objekt;
- dobar je za payload kod procedura;
- može se koristiti za audit starog i novog stanja;
- SQL Server omogućuje rad s JSON-om bez napuštanja relacijskog modela.

### Mane JSON-a u SQL Serveru

- ako se sve sprema kao JSON, gubi se dio relacijske kontrole;
- strani ključevi ne mogu direktno provjeravati vrijednosti unutar običnog JSON
  teksta;
- indeksiranje JSON vrijednosti je teže i često traži computed columns;
- složeni JSON može biti teži za održavanje od normaliziranih tablica;
- validacija poslovnih pravila može postati slabija.

### Kako to reći na obrani

```text
JSON u mom projektu nije zamjena za relacijski model. Koristim ga kao format za
izvoz event carda, za uvoz rezultata kroz payload i za audit promjena u triggeru.
Glavni podaci i dalje su normalizirani u tablicama.
```

---

## 18. Kratki sažetak za brzu obranu

Ako trebaš jako kratko objasniti cijeli projekt:

```text
Sirovi Kaggle podaci su denormalizirani, pa ih prvo učitavam u staging tablice.
Zatim ih normaliziram u relacijski model s eventima, borbama, borcima,
šifrarnicima, lokacijama i statistikama. Veze se provode primarnim i stranim
ključevima. Viewovi služe za čitljive izvještaje, procedure za ponavljajuću
logiku, trigger za audit, transakcije za sigurnu promjenu rezultata, a JSON za
uvoz i izvoz podataka prema aplikacijama.
```

Najvažnije rečenice:

- Relacijska baza koristi tablice i ključeve.
- Nerelacijske baze su fleksibilnije, ali često imaju slabiju relacijsku
  kontrolu.
- Normalizacija smanjuje redundanciju i anomalije.
- Denormalizacija je namjerno vraćanje redundancije radi čitanja ili praktičnog
  importa.
- Transakcija je logička cjelina koja se potvrđuje ili poništava.
- ACID jamči atomarnost, konzistentnost, izolaciju i trajnost.
- Dirty read je čitanje necommitane promjene.
- Lockovi kontroliraju istovremeni pristup podacima.
- Transaction log omogućuje rollback i recovery.
- View je spremljeni SELECT.
- Trigger je automatska reakcija baze na promjenu.
- Procedura je spremljeni T-SQL program.
- JSON je format razmjene podataka, ne nužno NoSQL baza.

---

## 19. Reference za dodatno čitanje

- Microsoft Learn: SQL Server schemas  
  <https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/create-a-database-schema>
- Microsoft Learn: Transactions  
  <https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql>
- Microsoft Learn: SQL Server locking and row versioning  
  <https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide>
- Microsoft Learn: Transaction log architecture and management  
  <https://learn.microsoft.com/en-us/sql/relational-databases/logs/the-transaction-log-sql-server>
- Microsoft Learn: `CREATE VIEW`  
  <https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql>
- Microsoft Learn: `CREATE TRIGGER`  
  <https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql>
- Microsoft Learn: `CREATE PROCEDURE`  
  <https://learn.microsoft.com/en-us/sql/t-sql/statements/create-procedure-transact-sql>
- Microsoft Learn: JSON data in SQL Server  
  <https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server>
- Microsoft Learn: Format query results as JSON with `FOR JSON`  
  <https://learn.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server>
- IBM: Big Data 4V overview  
  <https://www.ibm.com/topics/big-data>
