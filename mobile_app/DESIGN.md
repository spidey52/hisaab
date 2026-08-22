# Hisaab "Bahi-Khata Modern" redesign — implementation spec

This folder is a full UI redesign of `../mobile_app`. Controllers, repositories,
services, sync, and storage are untouched — this is a presentation-layer
redesign plus a handful of explicitly listed UX improvements.

## Design language

Inspired by the traditional bahi-khata ledger book, rendered as a modern
fintech app: warm paper ground, deep ink-green brand, passbook-style hero
card, ruled-ledger lists. Red/green keeps its universal dena/lena meaning.

## Color tokens — the only way to color anything

`lib/core/theme/app_theme.dart` defines `HisaabColors` (a `ThemeExtension`)
with light AND dark palettes. Access in widgets via the extension:

```dart
import '../../core/theme/app_theme.dart';
final colors = context.colors; // HisaabColors
```

Tokens: `page, surface, surfaceRaised, ink, muted, line, brand, brandDeep,
onBrand, onBrandFaint, green, greenDark, greenSoft, red, redSoft, amber,
amberSoft, settledSoft, heroTop, heroBottom`.

Migration map from the old static `AppColors` (which no longer exists):

| Old | New |
|---|---|
| `AppColors.green` | `context.colors.green` (use `.greenDark` for text/icons on `greenSoft`) |
| `AppColors.greenDark` | `context.colors.greenDark` |
| `AppColors.greenSoft` | `context.colors.greenSoft` |
| `AppColors.red` | `context.colors.red` |
| `AppColors.redSoft` | `context.colors.redSoft` |
| `AppColors.amber` | `context.colors.amber` |
| `AppColors.ink` | `context.colors.ink` |
| `AppColors.muted` | `context.colors.muted` |
| `AppColors.line` | `context.colors.line` |
| `AppColors.page` | `context.colors.page` |
| `Color(0xFFFFF3E7)` (soft amber) | `context.colors.amberSoft` |
| `Color(0xFFF0F3F1)` / `Color(0xFFF2F4F2)` (neutral chip) | `context.colors.settledSoft` |
| `Colors.white` as a surface/background | `context.colors.surface` |

Rules:
- Remove `const` from constructors when a color becomes non-const.
- NEVER hardcode a hex color in a page. `Colors.white` is allowed only for
  text/icons sitting on a solid `green`/`red`/`brand` fill.
- Soft borders: `Color.alphaBlend(fg.withValues(alpha: 0.16), softBg)`.
- The app now ships light + dark; every screen must read correctly in both.

## Typography

- Display face is Bricolage Grotesque via the `displayStyle(...)` helper in
  `app_theme.dart` (fontSize, fontWeight, color, letterSpacing, height).
- `textTheme.titleLarge`, `headlineSmall/Medium`, `displaySmall/Medium/Large`
  are already Bricolage w700 — page titles should just use
  `Theme.of(context).textTheme.titleLarge` etc. WITHOUT extra
  `fontWeight: w800` overrides.
- Body copy stays the platform font (SF Pro on iOS).
- Rupee amounts in lists: add
  `fontFeatures: const [FontFeature.tabularFigures()]` (exported by
  material.dart, no dart:ui import needed).

## Shape & components

- Cards: theme `CardThemeData` = radius 16, hairline `line` border. Don't
  override.
- Avatar/identity tiles: rounded squares radius ~14–15 (see `party_tile.dart`),
  NOT circles.
- Status chips: pill (radius 999) with soft bg + strong fg (see `_StatusPill`
  in `entry_tile.dart`).
- Bottom sheets: theme provides top-radius 24 + drag handle.
- Buttons/inputs/dialogs/switches/chips are themed — strip per-widget style
  overrides unless the widget is intentionally special.
- Direction semantics: gave = red −, got = green +. Text label must always
  accompany color (never color alone).
- Reference implementations to imitate: `lib/shared/widgets/entry_tile.dart`,
  `party_tile.dart`, `balance_widgets.dart` (`balanceTones`,
  `balanceKindLabel`, `KhataHeroCard`), `sync_strip.dart`,
  `entry_detail_sheet.dart`, `features/home/home_page.dart`.

## Structure changes already made

- 4 tabs: Home(0), Parties(1), Entries(2), More(3). Learn is no longer a tab;
  it opens from More as a pushed page.
- `SyncStrip` renders above the nav bar on every tab (in `app_shell.dart`) —
  pages must NOT add their own offline banners.
- Shared `showEntryDetailSheet(context, entry)` in
  `lib/shared/widgets/entry_detail_sheet.dart` is THE entry detail surface.

## Voice

- Keep the existing vocabulary exactly: "You gave / You got",
  "You will receive / You will pay", "Settled", "Party".
- Keep every `.tr` / `.trParams` call that exists; don't remove localization.
- Keep all `Semantics` widgets and labels; extend them if layout changes.
- No behavior changes beyond those explicitly requested per file.
