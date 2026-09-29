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
