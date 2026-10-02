# Interface languages

Qualia Engine supports English (`en`) and Russian (`ru`). On the first launch
Flutter resolves the operating-system language to a supported locale (English
is the fallback). Settings → Language applies the choice immediately and saves
it under `qualia.language` in local preferences.

## Resources

- `app/lib/l10n/languages/app_en.arb` — English template and message contracts.
- `app/lib/l10n/languages/app_ru.arb` — Russian translations with the same keys.
- `app/l10n.yaml` — Flutter `gen-l10n` configuration.
- `app/lib/l10n/generated/` — generated delegates and typed messages; do not edit.
- `app/lib/l10n/locale_controller.dart` — language preference persistence.
- `app/lib/l10n/app_strings.dart` — context accessor and explicit adapters for
  stable host-label registries and the built-in preview playground.
- `app/lib/l10n/module_strings.dart` — opt-in preview display labels, without
  mutating manifests or persisted module IDs.

Use `context.l10n.<message>` for new interface text. Add the key to **both** ARB
files. Use descriptive, stable keys; don't rename existing keys just to change
wording. Pass dynamic content through declared placeholders, not concatenated
translated fragments. Use ICU plural messages for counters. Marketplace dates
and compact statistics use `intl` with the active locale.

Run from `app/`:

```sh
flutter gen-l10n
dart analyze
flutter test
```

The localization tests check resource parity, placeholders, Russian plural
rules, persistence, live switching, menu actions and stable filter values.

## Translation boundaries

Host UI text, descriptions of built-in screens, built-in theme descriptions and
local preview control labels are translated. Names of external modules,
author-authored metadata/control labels, parameter values, license identifiers,
slugs, paths, JSON keys, API identifiers and diagnostic log records are not
rewritten. Preview option labels can change, but stored option values stay
unchanged. Unknown license names are preserved; only host placeholders such as
`Unspecified` and `Proprietary` are localized.

`hostLabel` is an adapter for existing **host-owned** registries, not a generic
translation service for arbitrary author strings. New widgets should use typed
messages directly. Navigation IDs and filter values remain locale-independent.
Standalone debug-terminal UI also uses these delegates and loads the saved
language at startup; the contents of log records remain their original text.
