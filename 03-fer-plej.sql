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

-- Reset glasanja (admin → Glasanje → Resetuj glasanje): briše sve glasove
create or replace function fp_reset()
returns void
language plpgsql security definer set search_path = public as $$
begin
  truncate fp_glasovi;
end $$;
grant execute on function fp_reset() to anon, authenticated;
