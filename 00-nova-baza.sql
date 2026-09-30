-- ═══════════════════════════════════════════════════════════════════
-- FC27 Liga — NOVA BAZA (prazan Supabase projekat)
-- Pravi sve tabele, dozvole i funkcije koje sajt koristi.
-- Pokrenuti u SQL Editoru novog projekta. Bezbedno i ako se pokrene više puta.
-- ═══════════════════════════════════════════════════════════════════

-- Igrači
create table if not exists igraci (
  id        serial primary key,
  ime       text not null,
  odeljenje text default '',
  zvezde    numeric default 3
);
alter table igraci add column if not exists firma text;            -- firma iz mejla (prikaz u kartici igrača)
alter table igraci add column if not exists plasman_prosle text;   -- prošlogodišnji plasman (unosi se u adminu)
alter table igraci add column if not exists sezona integer default 2;  -- koja je ovo sezona igrača u ligi (1 = prva)

-- Mečevi (liga + playoff)
create table if not exists mecevi (
  id            serial primary key,
  kolo          integer not null default 0,
  domacin       integer references igraci(id) on delete cascade,
  gost          integer references igraci(id) on delete cascade,
  gol_domacin   integer,
  gol_gost      integer,
  playoff_runda text,
  uneto_at      timestamptz
);

-- Istorija izmena
create table if not exists log (
  id       serial primary key,
  vreme    timestamptz not null default now(),
  akcija   text,
  detalji  text,
  izvor    text,
  napomena text
);

-- Pristup sa sajta (sajt i admin koriste javni ključ)
alter table igraci enable row level security;
alter table mecevi enable row level security;
alter table log    enable row level security;
drop policy if exists "igraci_all" on igraci;
drop policy if exists "mecevi_all" on mecevi;
drop policy if exists "log_all"    on log;
create policy "igraci_all" on igraci for all using (true) with check (true);
create policy "mecevi_all" on mecevi for all using (true) with check (true);
create policy "log_all"    on log    for all using (true) with check (true);
grant select, insert, update, delete on igraci, mecevi, log to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;


-- Vreme unosa rezultata (za "Poslednje rezultate" i formu)
alter table mecevi add column if not exists uneto_at timestamptz;

-- Pravila lige (tab Pravila)
create table if not exists pravila (id int primary key, tekst text, azurirano timestamptz default now());
alter table pravila enable row level security;
drop policy if exists "pravila_select" on pravila;
drop policy if exists "pravila_all" on pravila;
create policy "pravila_select" on pravila for select using (true);
create policy "pravila_all" on pravila for all using (true) with check (true);
grant select, insert, update, delete on pravila to anon, authenticated;


-- Mejlovi igrača — privatna tabela.
--    Javno (anon ključ) može samo da UPIŠE novi mejl; čitanje, izmena i brisanje nisu dozvoljeni.
--    Kad se igrač obriše, briše se i njegov mejl.
create table if not exists igraci_kontakt (
  igrac_id int primary key references igraci(id) on delete cascade,
  email    text not null
);
alter table igraci_kontakt enable row level security;
drop policy if exists "kontakt_insert" on igraci_kontakt;
create policy "kontakt_insert" on igraci_kontakt for insert with check (true);
grant insert on igraci_kontakt to anon, authenticated;
revoke select, update, delete on igraci_kontakt from anon, authenticated;

-- Admin: koji igrači imaju mejl (maskiran, npr. g***@4zida.rs)
create or replace function kontakt_status()
returns table(igrac_id int, maska text)
language sql security definer set search_path = public as $$
  select igrac_id, left(email, 1) || '***@' || split_part(email, '@', 2) from igraci_kontakt
$$;

grant execute on function kontakt_status() to anon, authenticated;

-- Izmena mejla postojećem igraču (samo ovde, u SQL Editoru):
--   update igraci_kontakt set email = 'novi@mejl.rs' where igrac_id = (select id from igraci where ime = 'Ime Prezime');

-- Automatsko osvežavanje sajta kad se nešto promeni (realtime)
do $$
declare t text;
begin
  foreach t in array array['igraci','mecevi','pravila','log'] loop
    begin
      execute format('alter publication supabase_realtime add table %I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════════════
-- FC27 Liga — FER-PLEJ GLASANJE
-- Pokrenuti jednom u Supabase SQL Editoru. Bezbedno i ako se pokrene više puta.
-- Sajt je u test režimu (glas bez mejl potvrde) dok je u index.html FP_VERIFIKACIJA = false.
-- ═══════════════════════════════════════════════════════════════════

-- Glasovi — bez javnog pristupa; sve ide kroz funkcije ispod i Edge funkciju.
create table if not exists fp_glasovi (
  glasac_id   int primary key references igraci(id) on delete cascade,
  za_id       int not null references igraci(id) on delete cascade,
  token       uuid not null default gen_random_uuid(),
  potvrdjen   boolean not null default false,
  poslato     timestamptz not null default now(),
  potvrdjeno  timestamptz,
  check (glasac_id <> za_id)
);
alter table fp_glasovi enable row level security;

-- Javni status: ko je glasao (bez podatka za koga)
create or replace function fp_status()
returns table(glasac_id int, potvrdjen boolean)
language sql security definer set search_path = public as $$
  select glasac_id, potvrdjen from fp_glasovi
$$;

-- Potvrda glasa klikom na link iz mejla (link važi 48h)
create or replace function fp_potvrdi(t uuid)
returns json
language plpgsql security definer set search_path = public as $$
declare g fp_glasovi;
begin
  select * into g from fp_glasovi where token = t;
  if not found then
    return json_build_object('ok', false, 'greska', 'Link nije ispravan ili je zamenjen novijim — koristi poslednji mejl koji si dobio.');
  end if;
  if g.potvrdjen then
    return json_build_object('ok', true, 'vec', true, 'glasac', (select ime from igraci where id = g.glasac_id));
  end if;
  if g.poslato < now() - interval '48 hours' then
    return json_build_object('ok', false, 'greska', 'Link je istekao. Pošalji glas ponovo sa sajta.');
  end if;
  update fp_glasovi set potvrdjen = true, potvrdjeno = now() where glasac_id = g.glasac_id;
  return json_build_object('ok', true, 'glasac', (select ime from igraci where id = g.glasac_id),
                                       'za',     (select ime from igraci where id = g.za_id));
end $$;

-- Rezultati (prikazuje ih admin): samo potvrđeni glasovi
create or replace function fp_rezultati()
returns table(za_id int, glasova bigint)
language sql security definer set search_path = public as $$
  select za_id, count(*) from fp_glasovi where potvrdjen group by za_id order by 2 desc
$$;

grant execute on function fp_status(), fp_potvrdi(uuid), fp_rezultati() to anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- TEST REŽIM (bez mejl verifikacije): glas se upisuje odmah kao potvrđen i može da se promeni.
-- Sajt ga koristi dok je u index.html  FP_VERIFIKACIJA = false.
-- Za finalnu verziju (sa verifikacijom) ovu funkciju OBRISATI:
--   drop function if exists fp_glasaj(int, int);
-- ═══════════════════════════════════════════════════════════════════
create or replace function fp_glasaj(glasac int, za int)
returns json
language plpgsql security definer set search_path = public as $$
begin
  if glasac is null or za is null or glasac = za then
    return json_build_object('ok', false, 'greska', 'Ne može se glasati za sebe.');
  end if;
  if not exists (select 1 from igraci where id = glasac) or not exists (select 1 from igraci where id = za) then
    return json_build_object('ok', false, 'greska', 'Igrač ne postoji.');
  end if;
  insert into fp_glasovi (glasac_id, za_id, potvrdjen, poslato, potvrdjeno)
  values (glasac, za, true, now(), now())
  on conflict (glasac_id) do update
    set za_id = excluded.za_id, potvrdjen = true, token = gen_random_uuid(), poslato = now(), potvrdjeno = now();
  return json_build_object('ok', true);
end $$;
grant execute on function fp_glasaj(int, int) to anon, authenticated;
