# FC27 Liga — Projektni kontekst (kompletni)

## ⚠️ Za agenta koji čita ovo

Pre nego što počneš bilo šta:
1. Pročitaj CELI ovaj dokument — strukturu, poznate greške, workflow, changelog
2. Identifikuj na kojoj grani se radi (Mile će navesti, ili pitaj pre nego što menjaš išta)
3. Uvek traži trenutni ZIP pre izmena — nikad ne radi na osnovu pretpostavke o stanju fajlova
4. Ne predlažaj izmene dok nisi siguran da razumeš kontekst projekta
5. Mile ne radi manuelne izmene koda — sve izmene su isključivo tvoja odgovornost
6. Na kraju sesije — obavezno upiši handoff u Changelog pre pakovanja ZIP-a

**Proaktivna primena konteksta:**
Poznavanje konteksta nije dovoljno — mora se primeniti bez čekanja da Mile pita. Primeri:
- Kada daješ uputstvo za upload, uvek navedi SVE relevantne grane (`main`, `razvoj-mile1`, `demo`) bez čekanja da se pita
- Kada menjaš fajl koji postoji na više grana, odmah sugeriši sync
- Ako primetiš potencijalni problem van trenutnog zadatka, napomeni ga
- **Sve što postoji i na javnom sajtu i u adminu (npr. Playoff prikaz) menja se SINHRONO na obe strane i mora izgledati isto.** Zajednički kod je označen komentarom `(identičan u index.html i admin/index.html)` — posle izmene proveriti da su blokovi u oba fajla identični

Cilj: Mile ne bi trebalo da mora da pita za stvari koje agent može da zaključi iz konteksta.

---

## Projekat
Interni EA FC 27 turnir (sezona 2026/27; prethodna sezona igrana na FC 26) za ~20 kolega u firmi INSPIRA.
Javni live sajt + admin panel za unos rezultata.
Mile (PM, bez programerskog iskustva) vodi razvoj kroz Claude chat.

## Stack
- **Frontend**: čisti HTML/CSS/JS (bez frameworka), 2 fajla
- **Baza**: Supabase (PostgreSQL + real-time subscriptions)
- **Hosting**: Vercel (auto-deploy sa GitHub)
- **GitHub**: `github.com/milenkojaric90/INSPIRA-FIFA-2026-`
- **Live sajt**: `inspira-fifa-2026.vercel.app` (main grana)
- **Razvoj**: `inspira-fifa-2026-git-razvoj-mile1-milenkojaric90s-projects.vercel.app`

## Supabase
- **URL**: `https://yvyuqxlzbvcjdogeerdu.supabase.co`
- **Anon key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJvYnNiY3dvcGl4a3BodXdvaWJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5Njk2MDcsImV4cCI6MjA5MDU0NTYwN30.1n4TQlRQkfzGWwHcjl1DEWapEnWTNdBmwbt38ejdc0s`

## Šema baze
```sql
tabela: igraci
- id (serial, primary key)
- ime (text, not null)
- odeljenje (text)
- zvezde (numeric) -- rang tima 0.5-5.0

tabela: mecevi
- id (serial, primary key)
- kolo (integer, not null)
- domacin (integer, FK -> igraci.id, ON DELETE CASCADE)
- gost (integer, FK -> igraci.id, ON DELETE CASCADE)
- gol_domacin (integer, default null)
- gol_gost (integer, default null)
- playoff_runda (text, null = liga meč) -- 'O1-1','O1-2','O1-3' ... 'C4-3','P2-3', 'F', '3M'
- uneto_at (timestamptz, null) -- vreme PRVOG unosa rezultata; koristi se za "Poslednji rezultati"

tabela: log
- id, vreme, akcija, detalji, izvor ('admin'/'live'), napomena

tabela: pravila
- id (int, primary key) -- uvek 1 red, id=1
- tekst (text)
- azurirano (timestamptz)
```

**Tabela pravila** (SQL Editor, prod baza — jednom):
```sql
create table if not exists pravila (id int primary key, tekst text, azurirano timestamptz default now());
alter table pravila enable row level security;
create policy "pravila_select" on pravila for select using (true);
create policy "pravila_all" on pravila for all using (true) with check (true);
```
Bez ove tabele sajt prikazuje ugrađeni podrazumevani tekst (`PRAVILA_DEFAULT`), a admin ne može da snima.

**Nova sezona / dodavanje kolone** (SQL Editor, prod baza):
```sql
alter table mecevi add column if not exists uneto_at timestamptz;
truncate mecevi, igraci, log restart identity cascade;
```
Ako kolona `uneto_at` ne postoji, kod i dalje radi (automatski je preskače), ali "Poslednji rezultati" tada ne mogu da se poređaju po vremenu unosa.

RLS je enabled, sve politike su javne (SELECT i ALL za oba).
CASCADE delete je dodat naknadno — bez toga brisanje igrača bacalo je FK grešku.

## Struktura fajlova
```
repo/
├── index.html        ← javni sajt
├── supabase/
│   ├── 00-nova-baza.sql             ← SVE tabele, dozvole i funkcije za prazan Supabase projekat (bezbedno i više puta)
│   └── 02-nova-sezona-brisanje.sql  ← briše igrače, mečeve, log i mejlove (nova sezona)
└── admin/
    └── index.html    ← admin panel
```

---

## Javni sajt — index.html

### Tabovi
Pregled · Tabela · Mečevi · Strelci · Timovi · Playoff · Pravila


### Zaglavlje i navigacija
- Desktop (>900px): jedna sticky traka — grb + "FC27 LIGA" levo, tabovi (pilule) centrirani, LIVE desno; `<header>` je sakriven. Traka je uvek iste širine (1240px) na svim tabovima, i na Playoffu. `html { overflow-y: scroll }` — prostor za scrollbar je uvek rezervisan, pa se zaglavlje ne pomera između dugih i kratkih strana (isto i u adminu)
- Telefon: `<header>` sa grbom i nazivom, ispod sticky red sa tabovima (horizontalni skrol, aktivni tab se sam centrira, fade na desnoj ivici)
- Širina sadržaja `--wrap: 1240px`; na Playoff tabu samo sadržaj ide na 1900px (`body.po-wide`), zaglavlje ostaje isto

### Fudbaleri sa strane (dekoracija)
- 3 isečena igrača (bez pozadine, WebP, ugrađeni u `DECO_IGRACI`), providnost 24%
- Na svakom tabu (osim Playoffa) tačno 2 igrača: jedan u sredini levog, jedan u sredini desnog bočnog prostora, iste visine
- Svih 6 kombinacija parova (A-B, B-A, A-C, C-A, B-C, C-B) nasumično raspoređeno na 6 tabova pri svakom učitavanju (`DECO_RASPORED`, `decoPostavi()` u `tab()`)
- Prikazuju se samo na ekranima širim od 1500px; sakriveni na Playoffu (koristi celu širinu) i telefonu
- `goTab(name)` — prelazak na tab iz dugmadi na stranici
- Swipe na telefonu radi kroz svih 7 tabova (koristi listu `.ntab` dugmadi)

### Pregled — raspored
1. Baner `#hero` (~190px): grb, naziv, sezona i 4 statistike koje se računaju iz podataka (Odigrano, Lider, Najbolji napad, Najbolja odbrana — najmanje primljenih golova među igračima koji su igrali; kod istog broja prednost ima onaj sa više odigranih mečeva; klik vodi na odgovarajući tab); fotografija igrača desno. Statički HTML, render puni samo `#hero-prog`. Telefon: slika 132px + statistike 2×2
2. Ispod: levo Tabela (skraćena na 10), desno Poslednji rezultati i Sledeći mečevi. Telefon: prvo rezultati i mečevi, pa tabela
   - Mini tabela na telefonu: samo #, Igrač, Forma (W/D/L, najnoviji levo) i Pts — `tblHtml(..., mini=true)`, kolone `.mob-only` / `.mh`. Desktop prikaz mini tabele nepromenjen
- Slike (grb, igrači, favicon) su UGRAĐENE u HTML kao base64 (`data:` URI) — nema foldera `img/`, sajt radi i kad se preuzme samo `index.html`. Za zamenu slike: novu sliku konvertovati u base64 i zameniti `src` (grb se pojavljuje 3× u index.html i 1× u adminu)
- Ako slika ne postoji: blok se prikazuje bez nje (`onerror` uklanja sliku), bez praznih površina

### Pravila
- Samo čitanje; tekst iz tabele `pravila` (fallback `PRAVILA_DEFAULT`), render `pravilaHtml()` — isti kod u oba fajla
- Formatiranje: 1. linija = naslov, `N. NASLOV VELIKIM SLOVIMA` = sekcija (kartica), `* ` / `- ` = lista, `1. tekst` malim slovima = numerisana lista, red ceo velikim = istaknut

### Pregled
- Poslednji rezultati i Sledeći mečevi: ista mreža kolona u obe kartice (domaćin | rezultat 84px | gost | kolo 72px) — sve u liniji; Poslednji rezultati prikazuju i kolo (ili rundu plej-ofa)
- Poslednji rezultati (5) — sortirani po vremenu unosa (najnoviji prvi): `mecVreme()` = `uneto_at`, a ako kolone nema ili je prazna → vreme iz loga `REZULTAT_UNET` (ključ "Domaćin vs Gost"). Realtime osvežavanje ide sa 0.9s odlaganja (`zakaziLoad`) da stigne i log; isto vreme koristi i forma u tabeli, uključuju i playoff mečeve (oznaka npr. "ČF · M2"). Izmena postojećeg rezultata NE pomera meč na vrh (čuva se vreme prvog unosa); reset briše `uneto_at`. Log se više ne koristi za ovaj box.
- Sledeći mečevi (5) — (1) igrači se ne ponavljaju u listi, (2) prednost imaju mečevi igrača koji značajno zaostaju (2+ odigrana meča manje od najaktivnijeg; prikazuje se "zaostaje N"), (3) redosled kola. Ako nema 5 mečeva sa različitim igračima, lista se dopunjuje ostalima.
- Tabela (naslov "Tabela") — cela liga tabela skraćena na prvih 10 (`MINI_LIMIT`), senka (fade) preko poslednjih redova i dugme "Prikaži celu tabelu (još N)" / "Prikaži manje"; stanje ostaje i posle realtime osvežavanja (klasa `mini-open` na `#mini-tbl`); ista legenda i boje kao Tabela tab

### Tabela (Liga tabela)
- Kompletna tabela svih igrača
- Kolone: #, Igrač (zvezde + ime + odeljenje), Forma (W/D/L poslednjih 5 — NAJNOVIJI PRVI/levo, sa prstenom; redosled po vremenu unosa `uneto_at`, pa kolo), P, W, D, L, GF, GA, GD, Pts
- Sortiranje: bodovi → gol razlika → postignuti golovi → ime
- Highlight: 1.–4. ista zelena boja (povlašćeni — direktno u četvrtfinale); 5.–12. ista plava boja (osmina finala); isprekidana linija ispod 12. mesta; 13+ neutralno. Legenda ispod tabele
- Na mobilnom skrivene kolone: Forma, P, GF, GA (ostaje: #, Igrač, W, D, L, GD, Pts)

### Mečevi (Raspored i rezultati)
- Filter: dva dropdowna Igrač 1 vs Igrač 2
  - Oba odabrana = 2 meča između njih (domaćin/gost)
  - Samo jedan = svi mečevi tog igrača
  - Nijedan = svi mečevi
- Lazy load: bez filtera prikazuje prva 3 kola + dugme "Učitaj još"
- Sa filterom: učitava sve odjednom (malo podataka)
- D/G badge: zeleno "D" za domaćina, teal "G" za gosta
- Neodigrani: input polja za unos, Enter potvrđuje
- Odigrani: samo prikaz rezultata (javni sajt ne može da menja)
- Floating "SNIMI REZULTAT" dugme na mobilnom — pojavljuje se kad fokusiraš input

### Strelci
- Ranking po postignutim golovima — prikazuju se SAMO igrači sa bar 1 golom
- Prikazuje: zvezde, ime, odeljenje, GF/GA tekst, progress bar, broj golova, broj mečeva

### Timovi
- Baner na vrhu: vezene zakrpe Inspira grupa + EA Sports FC 27 (ugrađena slika, `.tim-banner`); generator link je uklonjen
- 10 kartica sa zvezdama (0.5★ do 5★) → klik otvara SoFIFA filter za taj rang
- SoFIFA linkovi: 5★=oah86, 4.5★=oah82, 4★=oah78, 3.5★=oah74, 3★=oah70, 2.5★=oah68, 2★=oah66, 1.5★=oah64, 1★=oah62, 0.5★=oah59

### Playoff
- Bracket za top 12 iz lige tabele (osmina 8v9, 5v12, 6v11, 7v10; 1–4 čekaju u četvrtfinalu)
- Osmina, četvrtfinale, polufinale: serija od 2 meča, pobednik po zbiru golova. 3. meč se igra samo ako je zbir golova posle 2 meča izjednačen (npr. 1:3 + 3:1 = 4:4). Finale i meč za 3. mesto: 1 meč
- Odlučujući meč (3. meč, finale, 3. mesto) ne može biti nerešen — unosi se rezultat posle penala
- Teniski prikaz (isti na sajtu i u adminu, `poKartica()` / `poBoardHtml()`): kartica para = zaglavlje (runda, M1 M2 M3 Σ) + red po igraču (seed, ime, rezultati po meču, zbir golova). Pobednik para zeleno, dobijeni meč beo/bold, nepotreban M3 šrafiran
- Admin: u ćelijama su polja za unos, ispod kolone dugme ✓ (nesnimljeno) / × (snimljeno, briše) / 🔒 (zaključano). Javni sajt: samo prikaz
- Desktop: 5 kolona (1/8, 1/4, SF, Finale, Pobednik), stranica šira na Playoff tabu (`body.po-wide`). Mobilni: izbor runde 1/8 · 1/4 · SF · F / 3.
- Logika je u `PO_DEF` + `poIzracunaj()` — ISTI kod u oba fajla, menjati na oba mesta
- Meč se računa samo ako igrači u redu odgovaraju trenutnom paru (ako se promeni pobednik ranije runde, stari mečevi sledeće runde se ignorišu)

---

## Admin panel — admin/index.html

### Tabovi
Igrači · Rezultati · Playoff · Pravila · Log

### Igrači — unos
- Čuvaju se SAMO 3 podatka: Ime i prezime, Mejl, Rang (zvezdice). Polje Odeljenje je uklonjeno; u zbirnom unosu ostale kolone (sektor i sl.) se preskaču

### Igrači — mejlovi
- Pojedinačni unos ima polje Mejl; zbirni unos prepoznaje kolonu sa mejlom (sadrži @), rang (0.5–5) i preskače kolonu sa zvezdicama (★☆)
- Postojeći igrač u paste-u → "dopuna": dodaje mejl ako ga nema i ažurira rang ako je drugačiji
- Mejl se upisuje u privatnu tabelu `igraci_kontakt` (javno: samo insert; čitanje/izmena/brisanje zabranjeni); za sada se ne koristi nigde na sajtu. Admin vidi samo maskiran mejl (`kontakt_status`): ✉ na čipu igrača, "+✉" = nema mejla (klik za dodavanje)
- Izmena postojećeg mejla samo kroz SQL (primer u `00-nova-baza.sql`)


### Pravila tab
- Textarea (nalepi/izmeni) + uživo pregled identičan sajtu; Sačuvaj (upsert id=1) / Poništi izmene; upozorenje pri zatvaranju stranice ako ima nesačuvanih izmena; log `PRAVILA_IZMENJENA`

### Playoff tab
- Desktop: šira stranica (`body.po-wide`, max 1560px), grid sa 5 kolona (1/8, 1/4, SF, Finale, Pobednik), meč za 3. mesto ispod
- Mobilni (≤700px): dugmad 1/8 · 1/4 · SF · F / 3. prikazuju jednu rundu; žuta tačka = runda ima neodigrane mečeve; podrazumevano se otvara prva nezavršena runda. Prikaz se menja pri resize-u preko granice
- Polja za unos rezultata ispod svakog para (M1, M2, M3 za serije; REZ za finale i 3. mesto)
- M2 se otključava posle M1; M3 samo kad je zbir golova izjednačen; broj pored igrača = ukupno golova u dvomeču; zaključana polja imaju 🔒
- × briše taj meč i sve naredne u seriji; ako izmena M1/M2 reši seriju, M3 se automatski briše
- Log: `PLAYOFF_REZULTAT`, `PLAYOFF_POBEDNIK`, `PLAYOFF_REZULTAT_OBRISAN`, `PLAYOFF_RESETOVAN`

### Igrači tab
- Dodaj igrača: ime, odeljenje, rang zvezde (0.5-5.0, klikabilne zvezdice)
- Dva režima unosa (prekidač Pojedinačno / Zbirno):
  - Pojedinačno: kao ranije, Enter u polju takođe dodaje
  - Zbirno: textarea za paste iz Excela/Google Sheets (TSV). Jedan red = jedan igrač; prva tekst kolona = ime, druga tekst kolona = odeljenje, broj 0.5–5 = rang, email (sadrži @) i redni brojevi se preskaču, zaglavlje "Ime i prezime" se ignoriše. Pregled pre dodavanja; duplikati i već prijavljeni igrači se preskaču. Igrači bez ranga dobijaju rang izabran zvezdicama. Jedan `insert` za sve + po jedan `IGRAC_DODAT` log unos po igraču
- Lista prijavljenih kao chip-ovi sa × za brisanje
- Dugme "Generiši raspored (dupli krug)" — confirm dialog pre akcije koji upozorava da briše sve mečeve i rezultate
- Raspored = round-robin dupli krug (svako sa svakim domaćin i gost)
- Neparan broj igrača → BYE sistem (automatski slobodan igrač po kolu)

### Rezultati tab
- Isti filter kao javni sajt (Igrač1 vs Igrač2 + Svi/Neodigrani/Odigrani)
- Slobodan igrač prikazan samo kada nema filtera
- Odigrani mečevi: inputi popunjeni sa rezultatom, mogu da se menjaju
- Neodigrani: prazni inputi
- Dugme ✓ na desktopu snima, × resetuje rezultat na null
- Floating "SNIMI REZULTAT" dugme na mobilnom
- Enter na inputu = snimanje

---

## Dizajn

### Paleta (nepromenjena)
- Pozadina `#0f1420`, kartice `#161d2e`, sekundarne površine `#1c253a`
- Zelena `#ADFF2F`, teal `#00C896`, crvena `#ff4060`, žuta `#ffc800`
- Plej-of zone u tabeli: 1.–4. zelena, 5.–12. plava `rgba(120,150,255,…)`

### Tipografija
- Barlow Condensed (italic 800–900): naslovi sekcija, naziv lige, rezultati, bodovi
- Barlow (500–700): navigacija, imena, podaci, opisi, zaglavlja tabela
- Cifre ujednačene širine (`font-variant-numeric: tabular-nums`) u tabelama i rezultatima
- Manje velikih slova i razmaka između slova u sitnim oznakama; zaglavlje tabele 12px

### Komponente
- Kartice: radius 12px, diskretni separatori `rgba(255,255,255,0.06)`
- Rezultat: `.rscore` (min-width 70px — staje i 10 : 12), poraženi igrač priglušen
- Hover u tabeli: sloj `background-image` na `td` (vidljiv i na obojenim zonama)
- Aurora u zaglavlju prigušena

### Mobile
- Tabovi: sticky na vrhu, horizontalni scroll bez scrollbara, centrirani
- Swipe levo/desno menja tab (ignoriše scrollable elemente)
- Swipe desno (nazad) uvek radi
- Swipe levo blokiran ako element ima horizontalni scroll koji nije na kraju
- Mečevi: igrači u jednom redu, inputi ispod (grid layout)
- Floating dugme za snimanje; `main` ima 96px donjeg razmaka na telefonu da dugme ne prekrije sadržaj

---

## Poznate greške i rešenja

### 11. Zaglavlje se pomera na kratkim stranama
**Šta se desilo**: Na kratkim tabovima (Strelci, Timovi) nema vertikalnog scrollbara, pa je stranica ~15px šira i centrirano zaglavlje se pomeri. U headless testovima se ne vidi (tamo nema scrollbara).

**Rešenje**: `html { overflow-y: scroll; }` — scrollbar je uvek prisutan.

**Lekcija**: Kad se nešto centrirano "pomera" između tabova, prvo proveriti razliku u visini strane / scrollbar.

### 10. Agent zna kontekst ali ga ne primenjuje proaktivno
**Šta se desilo**: Agent je znao da postoje tri grane (`main`, `razvoj-mile1`, `demo`) ali je dao uputstvo za upload samo na `main`. Mile je morao da pita — što je tačno vrsta back-and-forth koji treba eliminisati.

**Rešenje**: Dodata eksplicitna sekcija "Proaktivna primena konteksta" u onboarding uputstvo.

**Lekcija**: Čitanje konteksta i primena konteksta nisu ista stvar. Sve što se može zaključiti iz readme-a — treba zaključiti i reći bez čekanja da korisnik pita.

---

### 1. renderRaspored() rušio admin
**Šta se desilo**: Obrisali smo tab Raspored iz admina ali funkcija `renderRaspored()` je ostala pozvana u `loadAll()`. Tražila je DOM element koji više ne postoji, bacala grešku i prekidala izvršavanje — `renderRezultati()` nikad nije dolazio na red, admin bio prazan.

**Rešenje**: Ukloniti i poziv i samu funkciju iz koda kad se briše tab.

**Lekcija**: Kada se briše tab, uvek proveriti da li postoje pozivi te funkcije u `loadAll()` ili `render()`.

---

### 2. Dupla render() / renderStrelci() funkcija
**Šta se desilo**: Tokom iterativnih izmena, novi kod je bio dodat ispred zatvarajuće `}` stare funkcije umesto da je zameni. Rezultat: dve definicije iste funkcije, JS sintaksna greška, bela stranica.

**Rešenje**: Koristiti Python `str.find()` + `str.replace()` da se pronađe tačno mesto i zameni cela funkcija odjednom.

**Lekcija**: Nakon svake izmene pokrenuti `node --check` na ekstraktovanom JS-u pre pakovanja.

---

### 3. Extra `}` na kraju skripte
**Šta se desilo**: Tokom refaktorisanja `renderStrelci` u zasebnu funkciju, ostala je jedna `}` viška pre `load()`. Sintaksna greška.

**Rešenje**: Brojati `{` i `}` u skripti, razlika mora biti 0.

**Lekcija**: Uvek proveriti balans zagrada nakon strukturalnih promena.

---

### 4. ZIP sa extra folderom (fc26_check)
**Šta se desilo**: Fajlovi su bili kopirani u `fc26_check` folder pa zipovani zajedno sa `fc26_v5`. Korisnik je dobijao 2 foldera u ZIP-u.

**Rešenje**: Zipovati direktno `fc26_v5/` bez prethodnog kopiranja.

**Lekcija**: `zip -r output.zip fc26_v5/` — ne kopirati u međufolder.

---

### 5. Supabase null normalizacija
**Šta se desilo**: Nakon `update` na `null` u Supabase, vrednosti su se vraćale kao `undefined` ili prazan string u nekim slučajevima, pa `gol_domacin === null` check nije radio.

**Rešenje**: Normalizacija pri učitavanju:
```js
ME = (b.data||[]).map(m=>({...m, gol_domacin: m.gol_domacin??null, gol_gost: m.gol_gost??null}));
```

**Lekcija**: Uvek normalizovati nullable vrednosti iz Supabase.

---

### 6. CSS flex-wrap na mečevima — polupan layout
**Šta se desilo**: Pokušali smo `flex-wrap` na `.mrow` da pomerimo inpute ispod igrača na mobilnom. Rezultat: domaćin i gost su se razdvojili u zasebne redove.

**Pokušaj 1**: `flex-wrap: wrap` na `.mrow` — nije radilo, igrači se razdvajali.

**Pokušaj 2**: Wrapper div sa `flex-wrap` — delimično radilo ali nestabilno.

**Rešenje**: CSS Grid — `grid-template-columns: 1fr auto 1fr` na `.mrow-teams`. Garantuje da domaćin i gost uvek ostaju jedan naspram drugog, a srednja kolona (inputi/rezultat) je tačno onoliko koliko treba.

**Lekcija**: Za layout "dva elementa sa nečim u sredini" — uvek grid, nikad flex-wrap.

---

### 7. Swipe na Playoff tabu
**Šta se desilo**: Playoff bracket ima horizontalni scroll jer je širi od ekrana. `isScrollable()` funkcija detektovala je scroll i blokirala swipe u oba smera — korisnik bio zaključan na Playoff tabu.

**Pokušaj**: Blokirati swipe samo kada je element scrollabilan — blokiralo oba smera.

**Rešenje**: 
- Swipe desno (nazad) uvek radi bez provere
- Swipe levo blokiran samo ako scrollabilni element nije skrolan do kraja (`scrollLeft + clientWidth < scrollWidth - 10`)

**Lekcija**: Swipe desno (nazad) ne treba nikad blokirati — korisnik uvek mora moći da se vrati.

---

### 8. Mečevi sporo renderuju
**Šta se desilo**: 380+ mečeva u jednom DOM renderu, browser se "guši".

**Pokušaj 1**: `requestAnimationFrame` — vizuelno brže ali ne i stvarno brže.

**Rešenje**: Lazy load — prikazati prva 3 kola odmah, dugme "Učitaj još" za ostalo. Sa filterom (mali broj mečeva) učitava sve odjednom.

---

### 9. Strelci tab prazan
**Šta se desilo**: `function renderStrelci(){function renderStrelci(){` — dupla definicija nastala tokom zamene funkcije. JS parsira prvu `{` kao početak tela, drugu kao ugneždenu funkciju, gubi se zatvarajuća `}`.

**Rešenje**: `str.replace('function renderStrelci(){function renderStrelci(){', 'function renderStrelci(){')`.

---

## Workflow

### Kako Mile radi
1. Otvori Claude chat, pošalji kontekst MD + trenutni ZIP
2. Opiši šta treba da se promeni
3. Claude menja fajlove, pakuje ZIP
4. Mile raspakuje, uploada na GitHub (`razvoj-mile1` grana)
5. Vercel auto-deployuje preview
6. Testira na preview URL-u
7. Kad OK → merge na `main`

### Git grane
- `main` — produkcija, live sajt, prod baza
- `razvoj-mile1` — razvoj i testiranje, ista prod baza
- `demo` — prezentacijska grana, potpuno odvojena demo baza

### Baze podataka
- **Prod baza**: `https://yvyuqxlzbvcjdogeerdu.supabase.co` — koriste je `main` i `razvoj-mile1`
- **Demo baza**: `https://pzqwzhvqbmeazbvuditj.supabase.co` — koristi je samo `demo` grana
- Demo baza ima iste igrače i mečeve kao prod (snapshot od 08.04.2025.)
- Demo baza se ne dira osim kada svesno odlučimo da je ažuriramo

### Važna pravila
- Uvek uploadovati na `razvoj-mile1` prvo, nikad direktno na `main`
- Uvek proveriti na preview URL pre merge-a
- Kad menjamo `index.html` i `admin/index.html` — navesti koji se menja
- ZIP treba da sadrži samo folder projekta bez extras
- Nikad ne mergati `demo` u `main` (različiti Supabase keyevi!)
- Za izmene na `demo` grani — Claude pravi poseban ZIP sa demo keyevima

---

## TODO / Buduće dorade
- [ ] Login za admin panel (Supabase Auth — oko 30 min posla)
- [ ] Playoff bracket — prebaciti stanje iz localStorage u Supabase tabelu
- [ ] "Sledeći mečevi" — bolja logika za slobodnu ligu (ne po kolu)
- [ ] VS Code + Claude Code setup
- [ ] README.md ažurirati nakon svake sesije

### Handoff pravilo
Na kraju svake sesije, pre pakovanja ZIP-a, agent obavezno:
1. Doda novi unos u `## Changelog` sekciju (najnoviji na vrhu)
2. Upiše datum, šta je urađeno, ispravljeno, šta nije završeno, koji fajlovi menjani i status grane
3. Tek onda pakuje ZIP

Format unosa:
```
---
### [DD.MM.YYYY] — Kratak naslov sesije
**Urađeno:** ...
**Ispravljeno:** ...
**Nije završeno:** ...
**Fajlovi:** `index.html` / `admin/index.html` / oba / `readme.md`
**Grana:** `razvoj-mile1` → merged ✅ / čeka merge ⏳
         / `demo` (demo Supabase keyevi!) ⚠️
         / samo `readme.md`, bez deploy-a
---
```

---

## Changelog / Projektni dnevnik
---

### [29.09.2026] — Prelazak na Goranove naloge (nova Supabase baza)

**Urađeno:**
- Sajt i admin povezani sa novim Supabase projektom `fc27-liga` (`https://yvyuqxlzbvcjdogeerdu.supabase.co`, publishable ključ)
- Baza se pravi fajlom `supabase/00-nova-baza.sql`

**Napomena:**
- Stara baza (Miletova, `robsbcwopixkphuwoiba`) i demo baza se više ne koriste
- Novi GitHub repo i Vercel projekat su na Goranovom nalogu; za početak jedna grana `main`

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

---

### [29.09.2026] — Uklonjen Fer-plej, poravnanje rezultata

**Urađeno:**
- Fer-plej potpuno uklonjen sa sajta i iz admina (kod sačuvan van repo-a za eventualni povratak); Edge funkcija i SQL za glasanje uklonjeni
- Mejlovi igrača i dalje se čuvaju (privatno) pri unosu
- `supabase/00-nova-baza.sql` — kompletna baza za novi projekat, bez fer-pleja
- Poslednji rezultati / Sledeći mečevi: fiksne kolone, rezultat iste širine u svim redovima, kolo uvek prikazano → sve u liniji u obe kartice
- Mečevi: srednja kolona fiksne širine (unos i odigran meč), imena uvek na istim pozicijama

**Ispravljeno:**
- Rezultat i imena u "Poslednjim rezultatima" nisu bili u liniji sa "Sledećim mečevima" (i širi rezultat, npr. 10:12, pomerao je red)

**Nije završeno:** /

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md` + `supabase/`

---

### [29.09.2026] — Priprema za puštanje uživo

**Urađeno:**
- SQL objedinjen u `supabase/01-podesavanje-baze.sql` (kolona uneto_at, tabela pravila, fer-plej, mejlovi) i `supabase/02-nova-sezona-brisanje.sql` (brisanje podataka za novu sezonu)
- Poruka na Fer-plej tabu kad SQL nije pokrenut: "Glasanje još nije pokrenuto"

**Ispravljeno:** /

**Nije završeno:**
- Mejl verifikacija za fer-plej (Brevo + Edge funkcija + `FP_VERIFIKACIJA = true`)

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md` + `supabase/`

**Grana:** `razvoj-mile1` → pa merge na `main`

---

### [29.09.2026] — Fer-plej test režim (bez mejla), unos igrača: Ime · Mejl · Rang

**Urađeno:**
- `FP_VERIFIKACIJA = false`: glas se beleži odmah (SQL funkcija `fp_glasaj`, dodata u `supabase/01-podesavanje-baze.sql`) i može da se promeni
- Admin: formular i zbirni unos čuvaju samo ime, mejl i rang (odeljenje uklonjeno)
- Readme: koraci za prelazak na finalnu verziju sa verifikacijom

**Ispravljeno:** /

**Nije završeno:**
- Finalna verzija: verifikacija mejlom (kod je spreman, uključuje se konstantom)

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md` + `supabase/01-podesavanje-baze.sql`

**Grana:** `razvoj-mile1` → čeka merge ⏳ (pre testa pokrenuti SQL za fp_glasaj!)

---

### [29.09.2026] — Fer-plej: provera podešavanja

**Urađeno:**
- Admin → Fer-plej: dugme "Proveri podešavanje" sa listom šta radi, a šta nedostaje
- Edge funkcija: režim provere (Secrets, tabele, Brevo ključ, verifikovan pošiljalac) — potrebno ponovo deployovati funkciju
- Javni sajt: jasnije poruke kad slanje ne uspe (funkcija ne postoji / odbija poziv)

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md` + `supabase/functions/fer-plej-glas/index.ts`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Fer-plej glasanje + mejlovi igrača

**Urađeno:**
- Javni sajt: tab Fer-plej (glasanje za jednog protivnika, potvrda linkom na mejl, prikaz ko je glasao)
- Admin: mejl u pojedinačnom i zbirnom unosu (Ime · Mejl · Rang, kolona sa zvezdicama se preskače), dopuna mejla/ranga postojećim igračima, indikator mejla na čipu, tab Fer-plej sa rezultatima
- `supabase/01-podesavanje-baze.sql` (tabele `igraci_kontakt`, `fp_glasovi` + funkcije) i Edge funkcija `fer-plej-glas` (slanje mejla preko Brevo)

**Ispravljeno:**
- Zbirni unos: kolona sa zvezdicama (★★★★☆) se ranije upisivala kao odeljenje

**Nije završeno:**
- Podešavanje: SQL, Brevo nalog, deploy Edge funkcije i Secrets (vidi "Fer-plej — podešavanje")
- Admin i dalje nema login — ko zna adresu admina može da doda mejl igraču koji ga još nema

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md` + `supabase/`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Poslednji rezultati uvek po redosledu unosa

**Urađeno:**
- Rezervni izvor vremena unosa iz loga (`REZULTAT_UNET`) kada `uneto_at` ne postoji; realtime osvežavanje sa odlaganjem + praćenje novih log unosa

**Ispravljeno:**
- "Poslednji rezultati" su se ređali po kolu/rasporedu kada kolona `uneto_at` nije dodata u bazu (SQL nije pokrenut) — sada idu po stvarnom redosledu unosa i bez nje

**Nije završeno:**
- Preporuka: pokrenuti `alter table mecevi add column if not exists uneto_at timestamptz;` (najtačnije, ne zavisi od loga)

**Fajlovi:** `index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Pregled (telefon): tabela sa formom umesto brojeva

**Urađeno:**
- Mini tabela na Pregledu, samo na telefonu: uklonjeni W, D, L, GD; umesto njih forma (W/D/L kružići); Pts ostaje
- Desktop i tab Tabela nepromenjeni

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Baner: Najbolja odbrana umesto "Na redu"

**Urađeno:**
- 4. statistika u baneru na Pregledu: igrač sa najmanje primljenih golova (uz broj odigranih mečeva)

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Strelci samo sa golovima, forma hronološki

**Urađeno:**
- Strelci: igrači bez gola se ne prikazuju
- Tabela: forma prikazuje najnoviji rezultat prvi (levo, istaknut prstenom); redosled po stvarnom vremenu unosa

**Ispravljeno:**
- Forma je bila poređana po kolu, a ne po tome kada je meč odigran

**Nije završeno:** /

**Fajlovi:** `index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Zaglavlje fiksno na svim stranama, fudbaleri u parovima

**Urađeno:**
- Fudbaleri sa strane: na svakom tabu po jedan levo i jedan desno, centrirani u bočnom prostoru i iste visine; 6 različitih kombinacija parova, nasumično
- Dodati i na Timove i Pravila; na Strelcima više nema 3 preklopljena igrača

**Ispravljeno:**
- Zaglavlje se pomeralo na Strelcima i Timovima (scrollbar) — sada identično na svim tabovima, sajt i admin

**Nije završeno:** /

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Baner na Timovima, fudbaleri sa strane, zaglavlje isto na svim tabovima

**Urađeno:**
- Timovi: novi baner (zakrpe Inspira grupa + EA Sports FC 27), uklonjen generator link i `generator.png`
- Isečeni fudbaleri kao suptilna dekoracija sa strana: sva trojica na Strelcima, po jedan nasumično na Pregledu, Tabeli i Mečevima
- Zaglavlje i tabovi na istom mestu na svim tabovima (ranije se na Playoffu širilo), tabovi centrirani

**Ispravljeno:**
- Zaglavlje se pomeralo ulevo na Playoff tabu

**Nije završeno:** /

**Fajlovi:** `index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Slike ugrađene u HTML, uklonjeni avatari

**Urađeno:**
- Grb, fotografija igrača i favicon ugrađeni direktno u `index.html` i `admin/index.html` (base64); folder `img/` više ne postoji
- Uklonjeni avatari sa inicijalima (tabela, kartice, Strelci) — ideja za kasnije: generisani grb za svakog igrača

**Ispravljeno:**
- Preuzet `index.html` bez foldera `img/` prikazivao je sajt bez grba i fotografije

**Nije završeno:** /

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Redizajn v2 (kompaktniji i moderniji Pregled)

**Urađeno:**
- Uklonjena sekcija sa vezenim grbom (i slika `grb-vez.jpg`)
- Baner smanjen na ~190px; umesto opisa i dugmadi prikazuje 4 statistike sezone
- Pregled kao pregledna tabla: tabela levo, rezultati i mečevi desno
- Desktop: zaglavlje i navigacija spojeni u jednu sticky traku; tabovi kao pilule
- Avatari sa inicijalima u tabeli, karticama i Strelcima; forma kao kružići

**Ispravljeno:**
- Bez slika baner i sekcija ispod tabele ostavljali su velike prazne površine

**Nije završeno:** /

**Fajlovi:** `index.html` + `readme.md` (admin nije menjan)

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [29.09.2026] — Vizuelni redizajn (identitet Inspira lige)

**Urađeno:**
- Zaglavlje sa grbom, poravnato sa navigacijom i sadržajem; sadržaj proširen na 1240px
- Pregled: baner sa fotografijom igrača i napretkom sezone, redizajnirane kartice rezultata/mečeva (širi prostor za rezultat, duža imena u 2 reda, bolja prazna stanja), sekcija sa vezenim grbom ispod tabele
- Tipografija: Barlow za podatke i navigaciju, Condensed za naslove i rezultate, tabular cifre, čitljivije sitne oznake
- Tabela: čitljivije zaglavlje, separatori, hover koji radi i na obojenim zonama
- Playoff (sajt + admin, zajednički kod): čitljivije oznake, pobednik ispod finala (4 kolone umesto 5 — više mesta za imena)
- Admin: grb u zaglavlju i favicon (bez banera i fotografija)
- Slike u `img/` (optimizovane)

**Ispravljeno:**
- Mobilni: donji razmak `main` (96px) — ranije ga je poništavao `main { padding: 1rem }`
- Swipe nije išao na tab Pravila (lista je imala 6 tabova)
- Rezultat "10 : 12" se prelamao u tabu Mečevi

**Nije završeno:** /

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md` + novi folder `img/`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [28.09.2026] — Tab Pravila (sajt + admin)

**Urađeno:**
- Nova Supabase tabela `pravila` (SQL u Šemi baze)
- Javni sajt: tab Pravila (samo čitanje), kartice po sekcijama, 2 kolone na desktopu; realtime osvežavanje
- Admin: tab Pravila sa editorom i pregledom uživo; log filter "Pravila"
- Početni tekst pravila ugrađen kao `PRAVILA_DEFAULT`

**Ispravljeno:** /

**Nije završeno:**
- Pravilnik i sajt se ne slažu u 2 stvari: polufinale je u pravilniku 1 utakmica (sajt: serija 2+1), a u tabeli je 2. kriterijum međusobni skor (sajt: gol razlika) — čeka odluku

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳ (pre testa pokrenuti SQL za tabelu pravila!)

---

### [28.09.2026] — Pregled: skraćena tabela sa proširenjem

**Urađeno:**
- Box "Playoff zona" na Pregledu preimenovan u "Tabela"; prikazuje prvih 10 mesta sa fade senkom i dugmetom za proširenje na celu tabelu
- `tblHtml()` dobio parametar `limit`

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [28.09.2026] — Tabela: jedinstvene boje plej-of zona

**Urađeno:**
- 1.–4. mesto: jedna ista zelena boja (red, traka, broj mesta) — povlašćeni, idu direktno u četvrtfinale
- 5.–12. mesto: jedna ista plava boja — osmina finala
- Legenda svedena na dve stavke

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [28.09.2026] — Teniski prikaz playoffa (sajt + admin), plej-of zona u tabeli

**Urađeno:**
- Playoff: novi teniski prikaz para, zajednički kod (CSS + `PO_RUNDE`, `poKartica`, `poBoardHtml`) identičan u oba fajla; javni sajt sada ima isti desktop raspored i isti mobilni izbor runde kao admin
- Admin: dugme ispod kolone menja se ✓/× u zavisnosti od toga da li ima nesnimljenih izmena (`poDirty`)
- Imena u playoffu se prelamaju u 2 reda umesto skraćivanja
- Tabela: plej-of zona 5.–12. plavom nijansom + linija ispod 12. mesta + stavka u legendi; 1.–4. dobili levu traku u svojoj boji
- Readme: pravilo o sinhronim izmenama sajta i admina

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [28.09.2026] — Admin playoff: pregledniji desktop, mobilni po rundama

**Urađeno:**
- Desktop: proširen admin na Playoff tabu, veće kartice, polja i dugmad, mečevi raspoređeni po visini kolone
- Mobilni: izbor runde (1/8, 1/4, SF, F / 3.) umesto horizontalnog skrolovanja bracketa

**Ispravljeno:**
- Filter dugmad u Rezultatima (Svi/Neodigrani/Odigrani) su gasila i prekidač Pojedinačno/Zbirno na Igrači tabu

**Nije završeno:**
- Javni sajt Playoff tab i dalje ima stari (horizontalni) prikaz

**Fajlovi:** `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [28.09.2026] — Ispravka playoff logike + unos rezultata samo kucanjem

**Urađeno:**
- Svi inputi za rezultat (Mečevi na javnom sajtu, Rezultati i Playoff u adminu): `type="text" inputmode="numeric"`, max 2 cifre, `samoBroj()` odbacuje sve osim cifara — nema strelica, točkića miša ni strelica na tastaturi; na telefonu se otvara numerička tastatura

**Ispravljeno:**
- Dvomeč se odlučuje po zbiru golova, ne po bodovima (prethodno je 1:3 + 3:2 davalo 3:3 boda i otključavalo M3; sada je 4:5 i serija je rešena)

**Nije završeno:** /

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [28.09.2026] — Poslednji/sledeći mečevi, playoff serije, reset sezone

**Urađeno:**
- Nova kolona `mecevi.uneto_at` + helper `mecSnimi()` (u oba fajla) koji je upisuje pri prvom unosu i briše pri resetu; radi i ako kolona još ne postoji
- Poslednji rezultati: sortiranje po `uneto_at`, najnoviji prvi, uključeni playoff mečevi; uklonjeno čitanje loga
- Sledeći mečevi: bez ponavljanja igrača + prioritet igračima koji zaostaju 2+ meča
- Playoff: serije do 3 meča sa zaključavanjem polja, finale i 3. mesto jedan meč; admin unosi rezultate umesto klika na pobednika (`setPoWinner` uklonjen, dodati `savePoGame`, `resetPoGame`); javni sajt prikazuje rezultate mečeva
- Admin bracket: kolone se više ne skupljaju, bracket se skroluje horizontalno
- SQL za novu sezonu (kolona + brisanje igrača, mečeva i loga) — vidi Šema baze

**Ispravljeno:**
- Poslednji rezultati na drugim uređajima nisu prikazivali najnoviji rezultat: realtime `load()` se okidao na izmenu `mecevi` pre nego što je upisan log

**Nije završeno:**
- Rang (zvezde) postojećeg igrača ne može da se menja

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳ (pre testa pokrenuti SQL na prod bazi!)

---

### [28.09.2026] — Zbirni unos igrača u adminu

**Urađeno:**
- Igrači tab: prekidač Pojedinačno / Zbirno
- Zbirni unos: paste više redova iz tabele, parser (`parseBulk`), pregled (`renderBulkPreview`), snimanje (`dodajZbirno`)
- Preskakanje duplikata (unutar paste-a i u odnosu na već prijavljene, bez obzira na velika/mala slova)
- Enter u polju za pojedinačni unos dodaje igrača

**Ispravljeno:** /

**Nije završeno:**
- Rang (zvezde) postojećeg igrača i dalje ne može da se menja — samo brisanje i ponovni unos

**Fajlovi:** `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [28.09.2026] — Prelazak na novu sezonu (EA FC 27)

**Urađeno:**
- Branding FC26 → FC27 na javnom sajtu: `<title>`, logo, footer (`FC27 LIGA — 2026/27`), alt tekst generator banera
- Branding FC26 → FC27 u admin panelu: `<title>` (`Admin — FC27 Liga`) i logo
- Generator link na Timovi tabu: `fifamatchcreator.com/ea-fc-26` → `ea-fc-27`
- Format ostaje isti (liga dupli krug + playoff za 12)
- Dogovoreno: podaci prošle sezone se brišu i kreće se od nule (SQL: `TRUNCATE mecevi, igraci, log RESTART IDENTITY CASCADE;` na prod bazi)
- Važno: `log` tabela MORA da se obriše zajedno sa mečevima — "Poslednji rezultati" na Pregledu čitaju log i uparuju po imenima igrača, pa bi se stari rezultati prikazali ako isti igrači učestvuju ponovo

**Ispravljeno:** /

**Nije završeno:**
- `generator.png` verovatno prikazuje FC 26 grafiku — treba nova slika
- Proveriti da li `fifamatchcreator.com/ea-fc-27` radi
- Proveriti SoFIFA pragove (oah) za zvezdice kad se FC 27 ocene ustale
- Demo grana/baza nisu dirane

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md` (ZIP ne sadrži `generator.png` — ostaje postojeći u repo-u)

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [11.04.2026] — Swipe fix na Playoff tabu

**Urađeno:**
- Swipe logika refaktorisana — umesto `isScrollable()` koristimo `getScrollableParent()` koji vraća sam element
- Na `touchstart` se pamti `startScrollLeft` vrednost scrollable elementa
- Swipe desno (nazad) blokiran ako je korisnik bio skrolovan >5px unutar elementa — sprečava lažni tab switch pri skrolovanju bracketa
- Swipe levo (napred) i dalje blokiran dok bracket nije skrolovan do kraja
- Lekcija #7 u readme-u opisivala problem ali prethodno rešenje nije pokrilo slučaj brzog skrolovanja

**Ispravljeno:**
- Brzi scroll levo unutar Playoff bracketa više ne triggeruje swipe nazad na prethodni tab

**Nije završeno:** /

**Fajlovi:** `index.html`

**Grana:** `razvoj-mile1` → mergovan u `main` ✅

---

### [11.04.2026] — Log sistem (akcioni dnevnik)

**Urađeno:**
- Kreirana Supabase tabela `log` (id, vreme, akcija, detalji, izvor) sa RLS politikama
- Dodat `logujAkciju(akcija, detalji)` helper u oba fajla — beleži svaku akciju u bazu
- **Izvor**: `admin/index.html` loguje sa `izvor:'admin'`, `index.html` sa `izvor:'live'`
- Logovane akcije u adminu: unos/izmena/reset rezultata, dodavanje/brisanje igrača, generisanje rasporeda, playoff pobednik, playoff reset
- Logovana akcija na javnom sajtu: unos/izmena rezultata (saveFromMecevi)
- Novi **Log tab** u admin panelu sa tabelom: vreme, akcija (color-coded badge), izvor (🌐 Live / ⚙️ Admin), detalji
- Filter po tipu akcije (Rezultati / Igrači / Raspored / Playoff)
- Filter po izvoru (Live sajt / Admin)
- Filter po datumu (date picker)
- Dugme × Resetuj briše sve filtere
- Dugme ↻ Osveži reload-uje log iz baze

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → mergovan u `main` ✅

---

### [11.04.2026] — Log sistem (akcioni dnevnik)

**Urađeno:**
- Kreirana Supabase tabela `log` (id, vreme, akcija, detalji) sa RLS politikama
- Dodat `logujAkciju(akcija, detalji)` helper u admin panelu — beleži svaku akciju u bazu
- Logovane akcije: unos rezultata, izmena rezultata (sa starim vrednostima), reset rezultata, dodavanje igrača, brisanje igrača, generisanje rasporeda, playoff pobednik, playoff reset
- Novi **Log tab** u admin panelu — tabela sa vremenom, tipom akcije i detaljima
- Filter po tipu akcije (Rezultati / Igrači / Raspored / Playoff)
- Dugme za ručno osvežavanje loga
- Color-coded badge-ovi po tipu akcije (zelena/teal/žuta/ljubičasta)

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳


---

### [10.04.2026] — Playoff redesign za 12 igrača, Supabase integracija, vizuelne dorade

**Urađeno:**
- **Tabela highlight:** prošireno sa 2 na 4 mesta — zelena (1.), teal (2.), žuta (3.), narandžasta (4.); legenda i row highlight ažurirani svuda (Pregled, Tabela)
- **Pregled tab:** mini tabela prikazuje svih 12 igrača sa highlighted top 4; naslov "Playoff zona"
- **Playoff bracket — nova struktura za 12 igrača:**
  - Osmina finala: O1 (8v9), O2 (5v12), O3 (6v11), O4 (7v10)
  - Četvrtfinale: C1 (1 vs pob.O1), C2 (4 vs pob.O2), C3 (3 vs pob.O3), C4 (2 vs pob.O4)
  - Polufinale: P1 (pob.C1 vs pob.C2), P2 (pob.C3 vs pob.C4)
  - Finale centrirano između dva polufinalna meča (`align-items:stretch` + `justify-content:center`)
  - Pobednik — kolona "Pobednik", veći prikaz sa 🏆, vizuelno dominantniji
  - Meč za 3. mesta — potpuno odvojen ispod celog bracketa, horizontalni prikaz (meč → strelica → 🥉 pobednik), priglušene žute boje, jasno manje težine
- **Supabase integracija playoff stanja:** uklonjen localStorage; playoff mečevi se čuvaju u `mecevi` tabeli sa `playoff_runda` kolonom; javni sajt čita i gradi `window.PO_STATE`; liga mečevi filtrirani sa `playoff_runda IS NULL`
- **Admin panel — novi Playoff tab:** interaktivni bracket, klik na igrača = pobednik, snima u Supabase; funkcije `setPoWinner()`, `resetujPlayoff()`, `renderAdminPlayoff()`; `loadAll()` odvojeno filtrira liga i playoff mečeve
- **Reset bug fix:** `resetujPlayoff()` koristi `.delete().in('id', ids)` — prethodni `.neq('id',0)` nije brisao podatke

**Ispravljeno:**
- Centriranje polufinala/finala/pobednika (padding-top trikovi zamenjeni stretch+justify-content:center)
- Reset playoff nije brisao podatke iz Supabase
- Mini tabela na Pregledu prikazivala samo 4 umesto 12 igrača

**Nije završeno:** —

**Fajlovi:** `index.html` + `admin/index.html` + `readme.md`

**Grana:** `razvoj-mile1` → čeka merge ⏳

---

### [08.04.2026] — Uspostavljanje handoff, onboarding i proaktivnog konteksta

**Urađeno:**
- Dodat blok `Za agenta koji čita ovo` na vrh readme-a — agent mora pročitati ceo dokument pre nego što počne, uvek tražiti ZIP, ne raditi manuelne izmene
- Dodat `Handoff pravilo` u Workflow sekciju — agent na kraju svake sesije sam upisuje changelog pre pakovanja ZIP-a
- Dodata `Changelog` sekcija kao projektni dnevnik (najnoviji unos uvek na vrhu)
- Handoff format za grane proširen — dodana `demo` opcija sa napomenom o demo Supabase keyevima
- Uklonjena stavka "README.md ažurirati nakon svake sesije" iz TODO jer je sada deo automatskog workflow-a
- Dodata sekcija "Proaktivna primena konteksta" u onboarding — agent mora primeniti kontekst bez čekanja da Mile pita
- Dokumentovana lekcija #10 — agent zna kontekst ali ga ne primenjuje proaktivno (primer: grane za upload)

**Ispravljeno:** /

**Nije završeno:** /

**Fajlovi:** `readme.md`

**Grana:** samo readme, nema deploy-a

---
