# Tu día — Fase 1 (offline)

App para registrar y visualizar estados de ánimo a lo largo del día.
Este proyecto implementa **solo la Fase 1** descrita en el brief:
registro rápido, listado diario, separación automática por día, burbuja
con mezcla de color animada, e historial básico. Todo 100% local/offline.

## Cómo correrlo

Necesitas tener [Flutter](https://docs.flutter.dev/get-started/install)
instalado (incluye Dart), y Xcode (para iOS, requiere Mac) y/o Android
Studio (para Android) configurados.

```bash
flutter pub get
flutter devices        # confirma que ves un emulador o teléfono conectado
flutter run
```

Para probarlo en tu propio teléfono: conéctalo por USB con la depuración
habilitada (Android) o ábrelo con Xcode (iOS), y corre `flutter run`.

## Estructura del proyecto

```
lib/
  data/
    models/            # MoodEntry, MoodType — solo datos, sin lógica
    mood_catalog.dart   # lista de estados disponibles (icono, color, nombre)
    repositories/
      mood_repository.dart        # interfaz — Fase 2 implementará otra versión con Supabase
      local_mood_repository.dart  # implementación local (Fase 1)
  services/
    date_service.dart          # agrupar por día, formatear horas/fechas
    color_blend_service.dart   # mezcla de colores para la burbuja
  state/
    mood_provider.dart   # única fuente de verdad del estado de la app
  features/
    home/                # pantalla principal
    history/             # historial básico agrupado por día
  core/theme/            # colores y tema
```

## Por qué esta estructura, pensando en las fases 2 y 3

- **`MoodRepository` es una interfaz abstracta.** La Fase 1 la implementa
  con `SharedPreferences` (`LocalMoodRepository`). Cuando llegue Supabase,
  se agrega una `SupabaseMoodRepository` que implemente la misma interfaz
  y se cambia una sola línea en `main.dart` — ninguna pantalla se toca.
- **`MoodProvider` no sabe de dónde vienen los datos.** Solo conoce el
  repositorio a través de la interfaz, así que login/amigos/sincronización
  se agregan ampliando esta capa, no reescribiéndola.
- **`MoodCatalog` es la única fuente de verdad de los estados de ánimo.**
  Agregar, renombrar o quitar un estado es editar esta lista.
- **Fase 3 (widget):** cuando llegue el momento, se recomienda el paquete
  `home_widget`, que permite actualizar un widget nativo de iOS/Android
  desde este mismo código Dart. El repositorio y el catálogo ya están
  aislados de la UI, así que el widget solo necesita leer los mismos
  datos a través del `MoodRepository`.

## Qué falta a propósito

Login, Supabase, amigos, sincronización y el widget del jarrón **no**
están implementados todavía — corresponden a las fases 2 y 3, y el brief
pide validar completamente esta fase antes de avanzar.
