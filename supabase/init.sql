-- =====================================================================
-- FASE 2 · MoodApp "Tu día" — esquema inicial de Supabase
-- Pegar como proyecto entero en: Supabase Dashboard > SQL Editor
-- Ejecutar una sola vez (inicio idempotente; los create index/policy
-- usan if not exists donde aplica).
-- =====================================================================

-- ---------- PROFILES ----------
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text not null unique,
  friend_code text not null unique,
  created_at  timestamptz not null default now()
);

-- ---------- CATÁLOGO DE ESTADOS (editable, POR USUARIO) ----------
create table public.mood_catalog (
  id         uuid primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  label      text not null,
  emoji      text not null,
  color      bigint not null,      -- Color.toARGB32()
  is_special boolean not null default false,
  sort_order int  not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists mood_catalog_user_idx on public.mood_catalog (user_id);

-- ---------- REGISTROS DE ESTADO DE ÁNIMO ----------
create table public.mood_entries (
  id         uuid primary key,       -- uuid generado por el cliente
  user_id    uuid not null references public.profiles(id) on delete cascade,
  mood_id    uuid not null,          -- sin FK a mood_catalog: si el amigo
                                     -- elimina el estado, las entradas viejas
                                     -- no se borran y se muestran como "❔"
  timestamp  timestamptz not null,
  logged_at  timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists mood_entries_user_ts_idx on public.mood_entries (user_id, timestamp);

-- ---------- AMISTADES (bidireccionales: 2 filas por amistad) ----------
create table public.friendships (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  friend_id  uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

-- ---------- GENERADOR DE CÓDIGO DE AMIGO ----------
create or replace function public.generate_friend_code() returns text
language plpgsql
set search_path = public
as $$
declare
  chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := '';
  i int;
begin
  for i in 1..6 loop
    code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return code;
end $$;

-- ---------- TRIGGER: perfil + código al registrarse ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  code text;
begin
  -- El username llega en raw_user_meta_data (asignado por la app al hacer
  -- signUp con el email determinista <username>@tu-dia.local). Se genera el
  -- código ANTES del insert para no pisar la restricción unique en
  -- friend_code; si el código choca con otro perfil, se reintenta.
  loop
    code := public.generate_friend_code();
    begin
      insert into public.profiles (id, username, friend_code)
      values (new.id, lower(trim(new.raw_user_meta_data->>'username')), code)
      on conflict (username) do nothing;
      exit;
    exception
      when unique_violation then null; -- código repetido: reintentar
    end;
  end loop;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- El trigger es de uso interno: no debe llamarse como RPC.
revoke execute on function public.handle_new_user() from public;

-- ---------- RPC: add_friend (amistad inmediata) ----------
create or replace function public.add_friend(code_input text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  f uuid;
begin
  select id into f
    from public.profiles
   where upper(friend_code) = upper(trim(code_input))
     and id <> auth.uid();
  if f is null then
    return false;
  end if;

  insert into public.friendships (user_id, friend_id)
  values (auth.uid(), f), (f, auth.uid())
  on conflict do nothing;
  return true;
end $$;

-- Restringe la ejecución de los RPCs a usuarios autenticados (por defecto
-- Postgres otorga EXECUTE a PUBLIC sobre funciones security definer).
revoke execute on function public.add_friend(text) from public;
grant execute on function public.add_friend(text) to authenticated;

-- ---------- RPC: remove_friend ----------
create or replace function public.remove_friend(friend_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.friendships
   where (user_id = auth.uid() and friend_id = remove_friend.friend_id)
      or (user_id = remove_friend.friend_id and friend_id = auth.uid());
end $$;

revoke execute on function public.remove_friend(uuid) from public;
grant execute on function public.remove_friend(uuid) to authenticated;

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
alter table public.profiles     enable row level security;
alter table public.mood_catalog enable row level security;
alter table public.mood_entries enable row level security;
alter table public.friendships  enable row level security;

-- profiles: cualquier autenticado lee (resolver códigos / ver nombres);
-- el dueño actualiza su propia fila.
create policy profiles_select on public.profiles
  for select to authenticated using (true);

create policy profiles_update on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- mood_catalog: CRUD del dueño + lectura de amigos.
create policy catalog_owner_all on public.mood_catalog
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy catalog_friend_read on public.mood_catalog
  for select using (
    exists (
      select 1 from public.friendships f
       where f.user_id = auth.uid() and f.friend_id = mood_catalog.user_id
    )
  );

-- mood_entries: CRUD del dueño + lectura de amigos.
create policy entries_owner_all on public.mood_entries
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy entries_friend_read on public.mood_entries
  for select using (
    exists (
      select 1 from public.friendships f
       where f.user_id = auth.uid() and f.friend_id = mood_entries.user_id
    )
  );

-- friendships: cualquiera de los dos lados lee; solo el dueño borra su lado
-- (el borrado completo lo hace la RPC remove_friend).
create policy friendship_read on public.friendships
  for select using (user_id = auth.uid() or friend_id = auth.uid());

create policy friendship_delete on public.friendships
  for delete using (user_id = auth.uid());

-- =====================================================================
-- DATA API (PostgREST): exposición a la API de datos
-- =====================================================================
-- La app exige login: anon NO recibe privilegios sobre tablas; solo
-- usage del esquema. El acceso a filas lo gobierna RLS.
grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on public.profiles      to authenticated;
grant select, insert, update, delete on public.mood_catalog  to authenticated;
grant select, insert, update, delete on public.mood_entries  to authenticated;
grant select, insert, delete          on public.friendships  to authenticated;