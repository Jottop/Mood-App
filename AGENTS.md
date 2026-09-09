# MoodApp

Flutter app (Spanish UI) "Tu día": quick mood logging, per-day list,
color-mixing bubble, history calendar, and an editable mood catalog.
Offline only (SharedPreferences); Phase 1, no backend yet.

## Commands
- `flutter analyze` — required gate after every change. There are NO tests
  in this repo; this is the only verification.
- `flutter run` — run on a connected device/emulator.
- Demo APK: `flutter build apk --release --split-per-abi`, then hand the
  user `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

## Conventions
- All UI strings and code comments are in **Spanish** (code identifiers in
  English). Match this in new code.
- Use `Color.withValues(alpha:)` — never `withOpacity`.

## Architecture
- `main.dart` wires two `ChangeNotifierProvider`s:
  - `MoodProvider` — mood entries, indexed per day and ordered by
    timestamp (`.Asc` = chronological, `.Desc` = reversed).
  - `MoodCatalogProvider` — the editable catalog; `byId()` is O(1) and
    returns an "unknown" mood for deleted ids so old entries don't crash.
- Both persist through `*Repository` interfaces (local SharedPreferences
  impls) via `DebouncedPersistence`, flushed on app pause by
  `_LifecycleHandler`.
- Folders: `lib/features/{home,history,moods}`, `lib/state`, `lib/data`,
  shared UI in `lib/core/widgets`. The README structure section is stale
  (predates the editable catalog) — trust the code.

## Repo-specific gotchas
- `dart:ui.Gradient.sweep` throws if `colorStops` is omitted with anything
  but exactly 2 colors: always pass evenly spaced stops (see
  `_AuraSimplePainter`).
- Aura halo (`mood_sphere_visual.dart`): **concentric contiguous rings**
  growing outward — one per UNIQUE special color in **first-registration
  order** (via `_auraLayers`); the first touches the bubble and each next
  ring touches the previous (no gaps). Repetitions add NOTHING — no extra
  ring, no intensity boost (every ring is always alpha 0.6). Big bubble:
  one blurred stroke per ring (soft neon, `MaskFilter.blur`, sigma =
  `_auraBlurMargin`). Calendar (`_AuraSimplePainter`): same rings,
  blur-free, thinner and with a slight gap between them so they read in the
  small bubbles. Big spheres reserve a **fixed** vertical margin up front
  (so the layout never jumps as rings are added) via
  `MoodSphereVisual.auraReservedSpace(size)` — see `mood_bubble.dart`
  `FloatingSphere` and `day_detail_screen.dart` (which always shows the
  sphere, empty-bubble style included even with zero entries, with the
  same float/switch animation as Home).
- Day lists (`day_entry_list.dart`) are reorderable (long-press drag, like
  manage moods): `MoodProvider.reorderDayEntries(date, idsInDisplayOrder)`
  reuses the day's existing timestamps to persist order. Deletion is
  **instant + undo**: X animates the card out, `deleteEntry` runs, and a
  floating `SnackBar` shows "Deshacer" with a `_UndoProgressBar` that
  drains over 4s; undo calls `MoodProvider.restoreEntry` (same id +
  timestamp ⇒ same position). The editable hex field (`_applyHex`/
  `_syncHexText`) lives inside the custom-color dialog with a copy button —
  but the dialog tree is wrapped in `MediaQuery` with `viewInsets` zeroed
  (`showCustomColorPicker`) so the Android IME **never reflows the dialog**
  (it just covers it), and the dialog must stay **non-scrollable**: the old
  combo `TextField` + `AlertDialog(scrollable: true)` froze the whole app
  on some phones.
- Use `MaskFilter.blur` inside `RepaintBoundary`; avoid
  `ImageFiltered`/`ImageFilter.blur` in hot paint paths.
- The special-emotion marker everywhere is the shared bare `SpecialBadge`
  (`Icons.radar`, `AppColors.inkSoft`); keep it inline —
  badges that overflow their card break the grid layout.
- The 10-per-day warning (`showMoodLimitDialog`) is used in Home and
  DayDetail only.
- `calendar_screen.dart` also renders a `MonthlySummary` card
  (`monthly_summary.dart`) below the grid: top-6 moods of the visible
  month, bubble area ∝ usage % (pyramid cloud, jittered) using
  `MoodSphereVisual` (main-bubble design, no aura) with the % as
  overlay; legend centered as rows (dot + name, no %). Skips deleted moods
  via `catalog.byId(id).id == '_unknown'`.
- For UI work, load the repo skill `.opencode/skills/flutter-ui-ux`.