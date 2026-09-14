# Splash crema (fondo del logo) en el arranque

## Objetivo
Que al abrir la app, el splash (la pantalla de carga con el icono en el medio)
no sea negro sino crema, el color del logo: `#FBEEDC`.

## Causa raíz
- Dispositivo en modo oscuro + `values-night/styles.xml` usa
  `Theme.Black.NoTitleBar` → el splash nativo (`drawable-v21/launch_background.xml`
  con `?android:colorBackground`) sale negro.
- En Android 12+ el sistema dibuja el icono centrado sobre ese fondo negro.
- La app fuerza siempre tema claro (`AppTheme.light`), así que ese destello
  negro es inconsistente.

## Cambios

1. `android/app/src/main/res/values/colors.xml`
   - Agregar `<color name="launch_background">#FBEEDC</color>`.

2. `android/app/src/main/res/drawable/launch_background.xml`
   - Fondo `@android:color/white` → `@color/launch_background`.

3. `android/app/src/main/res/drawable-v21/launch_background.xml`
   - Fondo `?android:colorBackground` → `@color/launch_background`.

4. `android/app/src/main/res/values-night/styles.xml`
   - `LaunchTheme` y `NormalTheme`: parent `Theme.Black.NoTitleBar` →
     `Theme.Light.NoTitleBar` (forzar claro, coherente con la app que solo
     tiene tema claro).

5. `android/app/src/main/res/values-v31/styles.xml` (NUEVO, Android 12+)
   - `LaunchTheme` parent `Theme.Light.NoTitleBar` con
     `android:windowSplashScreenBackground` = `@color/launch_background` →
     el splash del sistema (icono centrado) queda sobre crema.

6. `pubspec.yaml`
   - Registrar `assets/icon/` en `flutter: assets:` para poder mostrarla en
     el splash de Flutter.

7. `lib/core/theme/app_colors.dart`
   - Nueva constante `logoBg = Color(0xFFFBEEDC)`.

8. `lib/main.dart` `_SplashScreen` (línea ~155)
   - Fondo crema (`AppColors.logoBg`) e icono en el medio
     (`Image.asset('assets/icon/app_icon.png')`, ~112px) con el
     `CircularProgressIndicator` (inkSoft) debajo.

## Verificación
- `flutter analyze` verde.
- Build + `adb install -r` en el A31 (ya conectado) para verlo de inmediato.

## Publicación
- Commit en español, minúsculas.
- `./tool/publish_release.ps1 -Version 0.3.0 -Build 12 -SupabaseUrl ... -SupabaseKey ...`.

## Nota
En Android 11- el splash nativo queda crema (sin icono); el icono centrado lo
garantiza el splash de Flutter que se ve justo después. El A31 está en
Android 12 → ahí el icono centrado lo pone el propio sistema.