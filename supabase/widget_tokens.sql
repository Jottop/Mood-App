-- =====================================================================
-- MoodApp "Tu día" — tabla widget_tokens
-- Token de SOLO LECTURA del widget de comparación.
--
-- La tarea de fondo del widget ya NO rota el refresh token de la sesión
-- (eso invalidaba el token que conserva la app abierta y deslogueaba cada
-- X min/horas). En su lugar, la app pide aquí un token opaco por usuario
-- (Edge Function `widget_token`) y la tarea de fondo lo presenta a
-- `widget_friend_bubble` para leer la burbuja del amigo sin tocar la
-- sesión.
--
-- Seguridad:
--  * Solo se guarda el hash SHA-256 del token, nunca el token en claro.
--  * RLS activo SIN políticas + REVOKE a anon/authenticated: la tabla es
--    solo alcanzable por el service role dentro de las Edge Functions.
--  * Un token robado solo autoriza a leer la burbuja de los amigos del
--    dueño (la función verifica la amistad); nunca a controlar la cuenta.
-- =====================================================================
create table if not exists public.widget_tokens (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  token_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists widget_tokens_token_hash_key
  on public.widget_tokens (token_hash);

alter table public.widget_tokens enable row level security;

-- Solo el service role (Edge Functions) puede leer/escribir esta tabla.
-- OJO: este proyecto NO hereda privilegios para service_role (los grants a
-- anon/authenticated se hicieron a mano), así que hay que concederlo de forma
-- explícita o las Edge Functions fallan con "permission denied".
revoke all on public.widget_tokens from anon, authenticated;
grant all on public.widget_tokens to service_role;