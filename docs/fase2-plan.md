# Fase 2 — MoodApp Online (Supabase) · Plan

> Estado: **planificado** (documentado, no implementado). Decisiones tomadas
> por el usuario en la sesión de planificación. Este documento es la fuente
> de verdad para implementar la Fase 2.

## Objetivo

Darle funcionalidades online a la app "Tu día":

1. **Login** con usuario y contraseña.
2. **Base de datos** en Supabase (Postgres) para todo lo relacionado con
   autenticación, login y creación de tablas.
3. **Amigos por código**: cada usuario tiene un código de amigo; al
   ingresar el código del otro se vuelven amigos.
4. Al tener un amigo, **ver su resumen de día y su calendario** (solo
   lectura).

## Decisiones acordadas

| Tema | Decisión |
|---|---|
| Acceso | **Login obligatorio**: la app abre en la pantalla de login; sin sesión no hay app. Los datos propios viven en la nube (visibles en varios dispositivos). |
| Identificador | **Solo username + código** (sin email visible). Implementación: Supabase autentica por email ⇒ se usa un email determinista `<username>@tu-dia.local`. El username debe ser único ⇒ el email es único. El usuario nunca ve/escribe su email. Se desactiva "Confirmar email" en Auth, así `signUp` devuelve sesión de inmediato. |
| Agregar amigos | **Inmediato**: ingresar el código del otro activa la amistad de ambos lados al instante (sin solicitaciones). |
| Setup Supabase | **Crear proyecto desde cero**; las claves van por `--dart-define`, nunca hardcodeadas. |

## Dependencias y configuración

- Dependencia nueva: `supabase_flutter: ^2.17.2`.
- `lib/core/config/env.dart`: `String.fromEnvironment('SUPABASE_URL')` y
  `String.fromEnvironment('SUPABASE_ANON_KEY')`.
- `main.dart`: `WidgetsFlutterBinding.ensureInitialized()` +
  `await Supabase.initialize(url: ..., anonKey: ...)` antes de `runApp`.
- `AndroidManifest.xml` (main): agregar
  `<uses-permission android:name="android.permission.INTERNET"/>`
  (en debug Flutter la agrega solo; en release hay que declararla).

## Base de datos — `supabase/init.sql`

Pegar el archivo `supabase/init.sql` completo en Supabase Dashboard → SQL
Editor. Contenido:

- **`profiles`**: `id` (PK → `auth.users`, on delete cascade),
  `username` (text UNIQUE), `friend_code` (text UNIQUE), `created_at`.
- **`mood_catalog`** (catálogo editable POR USUARIO): `id` (PK, uuid del
  cliente), `user_id`, `label`, `emoji`, `color` (bigint, `toARGB32()`),
  `is_special`, `sort_order` (posición en la lista), `created_at`.
- **`mood_entries`**: `id` (PK, uuid del cliente), `user_id`, `mood_id`
  (uuid sin FK para no borrar entradas si se elimina el catálogo), `timestamp`,
  `logged_at` (timestamptz), `created_at`. Índice `(user_id, timestamp)`.
- **`friendships`**: `(user_id, friend_id)` con PK `(user_id, friend_id)`,
  `check (user_id <> friend_id)` y cascade. Cada amistad son **2 filas**
  (A→B y B→A) para que la lectura de amigos sea simétrica.
- **Trigger `handle_new_user`** (after insert on `auth.users`, security
  definer): crea el `profile` con el username de `user_metadata` y genera un
  `friend_code` de 6 caracteres (alfabeto sin caracteres confusos,
  `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`) con reintento ante colisión.
- **RPC `add_friend(code text) -> bool`** (security definer): resuelve el
  perfil por `friend_code`, inserta las dos filas de amistad con
  `on conflict do nothing`; devuelve `false` si no existe ese código.
- **RPC `remove_friend(friend_id uuid)`** (security definer): borra las dos
  filas de amistad.
- **RLS** habilitada en las 4 tablas:
  - `profiles`: SELECT para cualquier autenticado (resolver códigos y ver
    nombres); UPDATE solo el dueño.
  - `mood_catalog` y `mood_entries`: **dueño = CRUD completo**
    (`user_id = auth.uid()`); **amigos = solo SELECT** vía
    `exists(select 1 from friendships f where f.user_id = auth.uid() and f.friend_id = <tabla>.user_id)`.
  - `friendships`: SELECT si soy cualquiera de los dos; DELETE solo mi lado.

## Arquitectura Dart

### Auth — `lib/features/auth/` + `lib/state/auth_provider.dart`

- `AuthProvider extends ChangeNotifier`: `signUp(username, password)`,
  `signIn(username, password)`, `signOut()`, expone sesión, `loading` y el
  `Profile` propio (username + código de amigo).
- Normalización de username: minúsculas, regex `^[a-z0-9_]{3,20}$`.
  Email asociado: `'$username@tu-dia.local'`, y `data: {'username': ...}`
  en `signUp` (lo lee el trigger).
  Errores mapeados a español ("Este usuario ya existe",
  "Usuario o contraseña incorrectos").
- `LoginScreen`: pantalla de bienvenida con el gradiente/estilo actual,
  toggle Iniciar sesión / Registrarse.
- **Gate en raíz**: `_AppGate` — sin sesión → `LoginScreen`; con sesión →
  árbol principal. Al hacer logout se **desmontan los providers de datos**
  (vuelve a Login). La sesión se restaura entre arranques (supabase_flutter
  la persiste en SharedPreferences).

### Datos propios en la nube (sin tocar la UI)

Nuevos repos que **implementan las interfaces existentes**:

- `SupabaseMoodRepository implements MoodRepository`.
- `SupabaseMoodCatalogRepository implements MoodCatalogRepository`.

`MoodProvider`/`MoodCatalogProvider` y toda la UI local quedan igual.

- `loadAll()` → `select` por `auth.uid()`.
- `saveAll()` → semántica de "reemplazo total": `upsert` del set actual
  (los ids los genera el cliente) + `delete` de los ids que ya no existen
  (2 queries). Last-write-wins: suficiente para Fase 2 (documentado).
  `sort_order` = posición en la lista del catálogo.
- Offline mínimo: si una escritura falla se retiene el estado sucio y se
  reintenta en el siguiente flush / al volver a primer plano. El
  `DebouncedPersistence` no cambia.

### Reuso de pantallas para la vista de amigos (refactor dirigido)

`CalendarScreen` y `DayDetailScreen` están atadas a
`Consumer2<MoodProvider, MoodCatalogProvider>` y mutan datos. Para ver lo
del amigo se introduce una **interfaz de datos de solo lectura**:

- `MoodViewData` (nueva): `allEntries`, `entriesForDateAsc/Desc(date)`,
  `byId(moodId)` (resuelve color/label/emoji/isSpecial) y `catalogMoods`.
- `LocalMoodViewData(provider, catalog)`: adaptador que envuelve lo local
  (comportamiento idéntico).
- `FriendMoodViewData`: snapshot inmutable cargado del amigo
  (entries + catálogo).
- Refactor: `CalendarScreen`, `DayDetailScreen` y `DayEntryList` reciben
  `MoodViewData` + flag `readOnly`. En modo amigo: sin grilla para agregar,
  sin reset del día, sin "×" ni reorder en `DayEntryList`. El
  comportamiento local debe quedar **idéntico**.
- Extraer `_MoodSummary` → widget público `MoodSummary` (lo usan Detalle del
  día y el perfil del amigo).

### Amigos — `lib/features/friends/` + `lib/state/friends_provider.dart`

- `FriendsProvider extends ChangeNotifier`: `fetchFriends()` (join
  `friendships` + `profiles`), `addFriend(code)` → RPC, `removeFriend(id)`
  → RPC; expone lista (username, código, membresía desde).
- `FriendsScreen`: cabecera con **tu username y tu código de amigo**, botón
  "Agregar amigo" (diálogo para pegar el código ajeno) y lista de amigos.
  Código inválido → SnackBar "No se encontró ningún usuario con ese código".
- `FriendProfileScreen(friend)`: "resumen de día" del amigo — burbuja grande
  con los colores de HOY del amigo (reutiliza `FloatingSphere` + auras de sus
  emociones especiales), el `MoodSummary` del día, y acceso al **calendario**
  read-only → ver el mes y tocar un día para ver su detalle read-only.

### Punto de entrada

- En el `_Header` del Home: botón de icono **Amigos** (p. ej.
  `Icons.group`) y avatar con menú de **Cerrar sesión**.

## Orden de implementación

1. Deps + `env.dart` + init en `main` + INTERNET en manifest.
2. Aplicar `supabase/init.sql` en el dashboard (verificar tablas/RLS).
3. `AuthProvider` + `LoginScreen` + gate; probar signUp/signIn/restore/logout.
4. Repos de Supabase para datos propios (verificar que el flujo local
   funciona igual: agregar/borrar/reordenar).
5. Refactor `MoodViewData`/`readOnly` + extraer `MoodSummary`
   (verificación local).
6. `FriendsProvider` + `FriendsScreen` (+ código propio) + RPCs.
7. `FriendProfileScreen` (resumen hoy + calendario read-only) + navegación.
8. `flutter analyze` limpio, actualizar `AGENTS.md` y `README.md`.

## Compilación con claves

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

Idem para `flutter build apk --release --split-per-abi`.

## Riesgos y alcance fuera de Fase 2

- **Privacidad**: RLS de amigo solo lectura; el usuario controla quitando
  amigos.
- **Sin reset de contraseña** (el patrón pseudo-email no permite recovery
  por email). Documentado; migrable a email real después.
- **Sin realtime**: la vista del amigo se refresca al abrir su perfil.
  El esquema no impide agregar realtime después.
- **Multi-dispositivo** = last-write-wins ("reemplazo total").