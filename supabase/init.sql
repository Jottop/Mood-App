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
  -- Personalización del perfil (visible por los amigos): alias opcional,
  -- avatar 'fruit_0..fruit_4' (o null = inicial) y los colores de la
  -- píldora (por defecto cream/creamInk de la app).
  alias       text,
  avatar      text,
  pill_bg     bigint not null default 0xFFFBF3DE,
  pill_fg     bigint not null default 0xFF7A6A3F,
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

-- Sin índice adicional sobre friend_id: la tabla es diminuta y el PK
-- (user_id, friend_id) ya cubre la lectura "mis amigos" (lado user_id).

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

-- ---------- TRIGGER: perfil + código + catálogo inicial al registrarse ----------
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

  -- Catálogo inicial solo si el perfil quedó creado (defensivo; en la
  -- práctica el username no choca porque el email determinista es único).
  if exists (select 1 from public.profiles where id = new.id) then
    insert into public.mood_catalog (id, user_id, label, emoji, color, is_special, sort_order)
    values
      (gen_random_uuid(), new.id, 'Feliz',   '😊', 0xFFFFC501::bigint, false, 0),
      (gen_random_uuid(), new.id, 'Triste',  '😢', 0xFF1D8FFF::bigint, false, 1),
      (gen_random_uuid(), new.id, 'Ansioso', '😰', 0xFFF3ABFE::bigint, false, 2),
      (gen_random_uuid(), new.id, 'Enojado', '😡', 0xFFFD6B6B::bigint, false, 3),
      (gen_random_uuid(), new.id, 'Neutral', '😐', 0xFF57B634::bigint, false, 4),
      (gen_random_uuid(), new.id, 'Cansado', '😴', 0xFFAA8DF6::bigint, false, 5)
    on conflict do nothing;
  end if;

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
  -- Los códigos se guardan en mayúsculas y el cliente ya los normaliza
  -- (trim + to_upper + alfanuméricos). Comparar la columna directamente
  -- (no upper(col)) permite que use el índice único profiles_friend_code_key.
  select id into f
    from public.profiles
   where friend_code = upper(trim(code_input))
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
  -- Calificamos las columnas con el alias `f`: el parámetro `friend_id`
  -- sombrea la columna `friendships.friend_id` (error 42702 sin esto).
  delete from public.friendships as f
   where (f.user_id = auth.uid() and f.friend_id = remove_friend.friend_id)
      or (f.user_id = remove_friend.friend_id and f.friend_id = auth.uid());
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

-- profiles: el dueño y sus amigos leen (username + código); los códigos de
-- gente ajena no se resuelven con la tabla sino con el RPC add_friend. El
-- dueño actualiza su propia fila. `(select auth.uid())` se evalúa una sola
-- vez por consulta (initplan) en vez de por fila.
create policy profiles_select on public.profiles
  for select to authenticated using (
    (select auth.uid()) = id
    or exists (
      select 1 from public.friendships f
       where f.user_id = (select auth.uid()) and f.friend_id = profiles.id
    )
  );

create policy profiles_update on public.profiles
  for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- mood_catalog: el dueño escribe; él y sus amigos leen (una sola política
-- SELECT con OR evita evaluar dos políticas por fila).
create policy catalog_select on public.mood_catalog
  for select using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.friendships f
       where f.user_id = (select auth.uid()) and f.friend_id = mood_catalog.user_id
    )
  );
create policy catalog_insert on public.mood_catalog
  for insert with check ((select auth.uid()) = user_id);
create policy catalog_update on public.mood_catalog
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy catalog_delete on public.mood_catalog
  for delete using ((select auth.uid()) = user_id);

-- mood_entries: el dueño escribe; él y sus amigos leen.
create policy entries_select on public.mood_entries
  for select using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.friendships f
       where f.user_id = (select auth.uid()) and f.friend_id = mood_entries.user_id
    )
  );
create policy entries_insert on public.mood_entries
  for insert with check ((select auth.uid()) = user_id);
create policy entries_update on public.mood_entries
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy entries_delete on public.mood_entries
  for delete using ((select auth.uid()) = user_id);

-- friendships: cualquiera de los dos lados lee; solo el dueño borra su lado
-- (el borrado completo lo hace la RPC remove_friend).
create policy friendship_read on public.friendships
  for select using ((select auth.uid()) = user_id or (select auth.uid()) = friend_id);

create policy friendship_delete on public.friendships
  for delete using ((select auth.uid()) = user_id);

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