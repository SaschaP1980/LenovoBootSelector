# Localization architecture

Lenovo Boot Selector localizes all **product-controlled user-facing text** through one deterministic Windows PowerShell 5.1-compatible localization layer.

## Supported locales

The required locale set is:

- `en-US` — canonical default and fallback;
- `de-DE` — fully supported German UI.

`Resolve-LocaleIdCore` normalizes supported locale IDs case-insensitively. Unknown or invalid locale values fail safely to `en-US`.

## Source of truth

The canonical string inventory lives in:

`src/Core/Localization.ps1`

`Get-LocalizationCatalogCore` owns the semantic key catalog. Every supported locale must expose the same key set. Translation data is ordinary inert PowerShell data; no translation value is dynamically executed.

The public pure-core API is:

- `Get-SupportedLocaleIdsCore`
- `Resolve-LocaleIdCore`
- `Get-LocalizationCatalogCore`
- `Get-LocalizationKeySetCore`
- `Test-LocalizationCatalogParityCore`
- `Get-LocalizedStringCore`

The application-level API is:

- `Get-ActiveLocale`
- `Set-ActiveLocale`
- `Get-LocalizedString`

UI and presentation code should use `Get-LocalizedString`. Pure core code that needs localized product presentation receives an explicit locale and uses `Get-LocalizedStringCore`.

## Fallback semantics

Lookup is deterministic:

1. normalize the requested locale;
2. read the key from the active locale;
3. if the active catalog does not contain the key, try `en-US`;
4. if the key is unknown to the canonical English catalog as well, return the key itself as a visible deterministic fail-safe.

The permanent catalog-parity gate normally prevents step 3 from being needed for a committed supported locale, but the fallback remains part of the runtime contract.

Both positional and named formatting are supported. Named placeholders use values such as `{Model}` or `{Version}`; positional formatting uses normal PowerShell `-f` placeholders.

## Settings and migration

Localization uses settings schema **6**.

The persisted localization properties are:

- `locale`;
- `localePreferenceSource`.

`localePreferenceSource` is the evidence for how the current language was chosen:

- `default` — no explicit user language choice has been established;
- `user` — the user explicitly selected a supported language;
- `migration-pending` — a one-time compatibility state for an ambiguous v0.8.0.0 German setting.

Migration is deliberate:

- no settings file → new installation → `en-US` with `default`;
- Pre-localization settings without an explicit locale migrate to `en-US`.
- schema 5 with `locale: "de-DE"` and no preference metadata is ambiguous because v0.8.0.0 used the same serialized state for both the incorrect automatic migration and a possible explicit user choice;
- that ambiguous state is preserved temporarily as `de-DE` with `migration-pending` and requires one explicit English/German choice;
- an explicit supported choice is persisted with `localePreferenceSource: "user"` and is never changed automatically afterward;
- invalid/unknown locale data falls back to `en-US`;
- current/default settings without demonstrable user preference remain `en-US`.

The v0.8.0.0 ambiguity is intentionally **not** resolved by guessing. On the next normal UI startup, Lenovo Boot Selector asks once which language to keep. Choosing English corrects the unintended migration; choosing German preserves German as an explicit user choice. The resulting `user` marker prevents future automatic migration from changing that choice.

`Set-ActiveLocale -Persist` records explicit user intent even when the selected locale already equals the active locale. This is required so choosing German in the one-time migration prompt can distinguish a genuine German preference from the historical ambiguous state.

## Startup recovery

The localization core and settings-preference core are included before `src/UI/StartupRecoveryDialog.ps1` in the runtime template.

Startup recovery cannot display the normal migration-choice dialog because it also handles failures that occur before full UI startup. `Get-StartupRecoveryLocale` therefore performs a narrow read-only settings lookup and reuses the canonical locale-resolution rule:

- pre-localization settings without an explicit locale → English;
- explicit `user` preference → selected supported locale;
- `migration-pending` schema-5 German → German temporarily, until normal startup can ask for the explicit choice;
- missing/invalid/default-without-user-evidence → English.

Startup recovery never changes settings.

## What is localized

All product-controlled visible application text belongs in the catalog, including:

- tray menu and popup;
- language/settings presentation;
- default and one-time boot-target presentation;
- product-supplied Friendly/Storage/NVMe/USB descriptions;
- dialogs, buttons, accessible labels, tooltips, empty/busy/error states;
- maintenance/setup/repair/remove UI;
- update UI and rollback/result presentation;
- startup recovery;
- diagnostic export presentation.

## What is not translated

Do not artificially translate externally supplied or technical identity data:

- firmware descriptions;
- physical drive model names;
- GUIDs and Boot#### identities;
- paths and filenames;
- diagnostic event names/codes;
- structured error categories/stages;
- TaskBroker operation names;
- schema/property names;
- workflow/status contexts.

A firmware or drive description may be embedded into a localized surrounding sentence, but the external value itself remains unchanged.

## Update-worker and installer errors

Technical update-worker errors remain structured diagnostic data. UI code must not directly render raw worker exception text as localized product copy.

The standalone post-exit update installer cannot call the active WinForms localization service. The tray therefore supplies its rare visible fallback text from the central catalog before launching the helper. Those strings are transported as UTF-8 Base64 command-line data; the helper does not implement its own language branch.

## Deterministic runtime closure

`src/Core/Localization.ps1` and localization consumers enter the generated single-file runtime only through the existing template include registry in:

`src/App/LenovoBootSelector.template.ps1`

There is no runtime locale-file discovery, network translation, or uncontrolled resource lookup. `tools/build_runtime.py --check` remains the authoritative deterministic runtime-closure check.

## Adding or changing user-visible text

For any new product-controlled visible text:

1. choose a semantic key rather than using the English or German wording as the key;
2. add the key to both `en-US` and `de-DE`;
3. keep placeholders semantically equivalent in both translations;
4. consume the key through `Get-LocalizedString` or, in pure core, `Get-LocalizedStringCore`;
5. add focused tests when formatting, fallback, safety wording, or migration semantics change;
6. run the permanent Python gates and native Windows PowerShell 5.1 suite.

Do not add `if ($Language -eq ...)` or equivalent distributed language branches.

## Permanent gates

LBS-17 establishes permanent coverage for:

- English and German key-set parity;
- duplicate-key rejection;
- English default/fallback semantics;
- invalid-locale handling;
- deterministic positional/named formatting;
- settings persistence and schema-4 migration;
- generated-runtime localization closure;
- selected Friendly/Storage/Update/Maintenance semantics in both languages;
- direct visible-literal prevention in affected UI/presentation/template surfaces;
- native Windows PowerShell 5.1 language selection, persistence, reload, migration, parity, and lookup.

The dedicated native suite is:

`tests/Test-LocalizationRuntime.ps1`

It emits:

`LOCALIZATION TOTAL <passed>/32`

and is part of the mandatory GitHub-hosted Windows PowerShell 5.1 Candidate gate.

## Safety boundaries

Localization must not change the boot or privilege architecture. The following remain invariant:

- tray process unelevated;
- privileged changes only through fixed allowlisted SYSTEM Scheduled Tasks;
- no arbitrary command/task/GUID/Boot####/device-path privilege channel;
- one-shot BootNext semantics;
- no permanent UEFI BootOrder / `{fwbootmgr} displayorder` mutation;
- no new SYSTEM executable;
- no PnP/device-arrival handler or polling;
- no unsupported physical USB-to-firmware mapping;
- updater remains user-controlled and unelevated.
