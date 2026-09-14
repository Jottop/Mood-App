# Actualización dentro de la app (sin salir al navegador)

## Objetivo
Que el botón "Descargar"/"Descargar e instalar" de la actualización baje el APK
con **progreso visible dentro de CamiMood** y lo instale sin abrir el navegador
ni la página hub. Hoy `launchAppDownload` (`lib/data/app_update.dart:93`) abre
Chrome con `url_launcher` → página externa.

## Arquitectura (sin páginas externas)
1. **Descarga** en Dart con `http` (ya es dependencia) + progreso por fracción,
   guardando el APK en `getTemporaryDirectory()` (`path_provider`, nueva dep).
2. **Integridad**: verificar SHA-256 del archivo contra `update.sha256`
   (`crypto`, nueva dep). Si no coincide → abortar con aviso.
3. **Instalación**: MethodChannel `moodapp/installer` en `MainActivity.kt` que
   expone el APK descargado con `FileProvider` y lo abre con
   `Intent.ACTION_VIEW` (`application/vnd.android.package-archive`). Android
   muestra su diálogo nativo de confirmación y resuelve la instalación.
   Android 8+ requiere dar una vez el permiso "Permitir instalar
   aplicaciones desconocidas" a CamiMood: la app detecta si falta
   (`canRequestPackageInstalls`) y abre la pantalla de ajustes del sistema con
   un botón, sin salir de la app.
4. El diálogo de confirmación final lo muestra Android (nativo, sobre la app,
   nunca una página web).

> Nota de e2e: el enfoque inicial de session silenciosa
> (`PackageInstaller.Session` + `commit`) quedaba colgado en el A31
> (`mProgress=0.8`, `mRelinquished=false`, `mFinalStatus=0`, esperando al
> verificador de Play Protect), igual que el histórico `-25` de Chrome.
> El flujo ACTION_VIEW + confirmación del usuario **sí completa la
> instalación** (validado end-to-end en el A31: se pasó del APK 0.5.0 al
> 0.6.0 de prueba). Los `PackageInstallReceiver.kt` y la session silenciosa
> se eliminaron; el `usesCleartextTraffic` era solo para el server local.

## Cambios

### Dart
- `lib/data/app_update.dart`
  - Eliminar `launchAppDownload` y el import de `url_launcher`. Nuevos:
    - `Future<String> downloadApk(update, onProgress(received, total, fraction))`
      → guarda en temp, reporta progreso, verifica SHA-256, devuelve la ruta.
    - `Future<void> runInAppUpdate(BuildContext context, update)` — orquesta:
      1) si falta permiso → dialog con "Abrir ajustes" (y se vuelve a comprobar);
      2) descarga con dialog de progreso (barra + %), no cerrable;
      3) abre el instalador nativo (`launchInstaller`) y la app queda esperando;
      4) snackbar avisando que Android confirma; fallo → snackbar con aviso claro.
- `lib/features/home/home_screen.dart:59` — la acción "Descargar" del snackbar
  llama a `runInAppUpdate(context, update)`.
- `lib/features/profile/settings_screen.dart:141` — el botón "Descargar" del
  dialog llama a `runInAppUpdate(context, update)`. Copia del texto: "Descargar"
  → "Descargar e instalar"; ajustar el texto secundario (ya no "la instalación
  te la confirma Android"). Subtitle del tile (línea 63): "…descargar." →
  "…descargar e instalar desde la app."
- `pubspec.yaml`: agregar `path_provider` y `crypto`; quitar `url_launcher`
  (solo se usaba aquí).

### Android
- `android/app/src/main/AndroidManifest.xml`
  - `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>`
- `android/.../kotlin/com/example/mood_app/MainActivity.kt`
  - Registrar `MethodChannel('moodapp/installer')` en `configureFlutterEngine`:
    - `canInstall` → `packageManager.canRequestPackageInstalls()` (API 26+;
      <26 → true).
    - `openInstallSettings` → intent `ACTION_MANAGE_UNKNOWN_APP_SOURCES` con el
      package (API 26+; fallback <26 a `ACTION_MANAGE_APPLICATIONS_SETTINGS`).
    - `launchInstaller(path)` → `FileProvider.getUriForFile(...)` +
      `Intent(ACTION_VIEW)` con `application/vnd.android.package-archive` y
      `FLAG_GRANT_READ_URI_PERMISSION`. Devuelve "ok" o error.
- `android/app/src/main/AndroidManifest.xml`
  - `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>`
  - `<provider android:name="androidx.core.content.FileProvider" .../>` con
    `<meta-data ... resource="@xml/file_paths"/>`.
- `android/app/src/main/res/xml/file_paths.xml` — `<cache-path name="apk_cache"
  path="."/>` (el APK vive en la carpeta temporal).

## UX / transparencia
- La app nunca sale a una página web. El único "salir" es el diálogo nativo de
  confirmación de Android y el cierre de la app al aplicar la actualización.
- Mientras corre el `adb install` normal no hay ningún cambio (firma debug igual).

## Verificación (e2e en el A31, sin publicar primero)
1. `flutter analyze` verde.
2. Build release (versionCode 13).
3. e2e local: la app del teléfono estaba en v0.4.0/13 de prueba. Se sirvió un
   `manifest.json` + un APK 0.5.0/14 con `adb reverse tcp:9000 tcp:9000` (mini
   servidor Dart en el PC) y `--dart-define=UPDATE_MANIFEST_URL=...`. Con la
   session silenciosa el flujo se quedaba colgado (ver nota de arquitectura);
   con ACTION_VIEW + FileProvider el flujo completo **funciona**: aviso →
   permiso → descarga con progreso (55 MB) → verificación SHA → diálogo nativo
   de Android (Play Protect + confirmar) → **la versión instalada pasó a una
   mayor (15)**. Validado con la sesión de instalación finalizando bien.
4. Publicar igual que siempre.

## Publicación
- Commit en español, minúsculas.
- `./tool/publish_release.ps1 -Version 0.4.0 -Build 13 -SupabaseUrl ... -SupabaseKey ...`
  con notas del cambio. El hub/manifiesto no cambia su forma: solo vuelca el
  0.4.0 real (los usuarios jamás ven el manifest de prueba).