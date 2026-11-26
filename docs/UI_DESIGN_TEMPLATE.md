# UI Design Template

## Action interaction colors

Owner-approved reference, 2026-11-26. The reference image shows a two-arrow refresh icon in four visual states on a black header surface. The following palette is the target design for action controls in the normal dark theme.

| State | Hex | RGB | Meaning |
| --- | --- | --- | --- |
| Disabled | `#777777` | 119, 119, 119 | Visible, unavailable |
| Normal | `#B8B8B8` | 184, 184, 184 | Available, idle |
| Hover | `#FF6E66` | 255, 110, 102 | Pointer over an available action |
| Active operation | `#E1251B` | 225, 37, 27 | An operation is actually running, where applicable |

The reference uses a black (`#000000`) background. Use the colors as semantic action-ink/accent tokens, with consistent optical size, alignment and stroke weight for icons. Preserve legibility on other surfaces. All actionable controls should share the hover accent; where hover is currently expressed by a surface fill, use an appropriate pale-red accent without sacrificing text contrast. The exact control-specific treatment is part of the migration inventory.

Disabled controls remain visibly subdued and cannot dispatch actions. Hover is not focus, press, selection, checked state, warning, error or success. Keep those independent semantics and system High Contrast accessibility intact. A running operation must not be inferred from a pointer hover. Do not use these action colors to recolor unrelated static text or status signals indiscriminately.

## Rollout status

This document records the approved **target design**, not an assertion that the current application already implements it.

- [LBS-182](https://github.com/SaschaP1980/LenovoBootSelector/issues/182): introduce the System Status and redesigned Refresh header controls, retaining the existing `#E1251B` hover convention for this issue. The Refresh icon is visible even when disabled at initial startup.
- [LBS-270](https://github.com/SaschaP1980/LenovoBootSelector/issues/270): low-priority application-wide migration to `#FF6E66` hover, including the new LBS-182 controls. Inventory all action surfaces, preserve actual operation and accessibility semantics, and verify native rendering and action admission at 100%/250% DPI in DE/EN.

No runtime, build, release or dependency change is implied by this documentation.

## LBS-270 rollout inventory (implementation checkpoint; qualification pending)

Normal-theme hover uses `#FF6E66` in action ink, or a contrasting edge when preserving an existing filled button is necessary. `#E1251B` stays the active-operation/relationship accent; checked and selected indicators keep their own meaning.

| Surface / owner | Previous presentation | Migration decision |
| --- | --- | --- |
| Tray root, language, portable preferences and maintenance submenus (`LenovoMenuRenderer`) | Selected/hot background; native text | Pale-red enabled pointer-hot text; keep full-width selected background, check, flags and arrows. Applies to Open, Autostart, languages, Export/Import, setup/remove, update check/install, diagnostic save/upload, Restart, Exit. |
| Main header Info and Refresh (`PopupComposition`, `RefreshPresentation`) | Lenovo red hover | Pale-red hover; active refresh and active Info relationship red; initial disabled glyph remains visible. |
| Header update notification | Pale-red hover and focus | Pale-red pointer hover only; native focus cue remains independent. Non-action status has no hover. |
| Normal boot targets and Manage rows (`BootEntryList`, `BootEntryRows`) | Dark row hover; selected/pending marker | Pale-red title on available hover; preserve selected/pending and hidden state backgrounds; no extra readiness probes on pointer movement. |
| Manage eye, reorder grip, pencil and alias clear | Red/gray/bright gray glyphs | Pale-red pointer hover, independently of existing Ctrl editing cue, hidden slash and drag cue. |
| Customize, Apply/Cancel alias, Undo/Cancel/Save, Restart and Use Default Once | Dark/red button surface hover | Pale-red ink or shared hover edge; retain native pressed/focus/disabled gates and contrast-safe fills. |
| Main navigation: Default Startup Target and Further Settings | Brighter row surface | Pale-red action title, preserve modal owner highlight and default-target disabled/pending ink. |
| Default picker rows including clear default | Dark hover and selected marker | Pale-red action title; selection marker, default state and action guards remain separate. |
| Further Settings: Autostart label/switch, language choices, setup/remove, update, diagnostics, preferences actions | Dark tile/selected fill, semantic destructive accent | Pale-red action title/icon or switch track outline; retain checked fill, selected language, destructive meaning, real focus perimeter and action dispatch. |
| All auxiliary Close controls, main/auxiliary custom scrollbars | Red close, bright red thumb | Pale-red close and thumb hover; preserve close ownership, scroll drag and track. |
| System Status read-only content | Semantic status and timestamps | No hover recoloring of read-only status labels or icons. Close/scroll covered above. LBS-274 status-symbol design excluded. |
| Regular notice, language, removal/restart confirmations, maintenance primary action (`Dialogs`, `MaintenancePresentation`) | Native flat dark/red surface | Shared pale-red hover edge, preserve contrast, focus, DialogResult and action ownership. |
| Portable preference view/actions and confirmation forms | Native flat gray/red surface | Shared pale-red hover edge; retain mode, selection and confirmation semantics. |
| Startup Recovery: Close, Open Diagnostics, Retry | Native flat buttons | Pale-red text hover with fallback literal if embedded C# failed to initialize; no new startup dependency. |
| All three active auxiliary connectors | System Status red; others child surface | Shared Lenovo red fill independent of pointer hover. Existing geometry, outline, dimmer and invalid-placement suppression unchanged. |
| Native Open/Save file choosers, fallback Windows MessageBox, native text caret/selection and OS title bar | System-controlled | Exception: retain operating-system interaction/accessibility rendering. No custom recolor of OS-owned UI. |
| High Contrast | Existing Windows system colors/contrast policy | Exception: suppress new pale-red custom hover overlay and preserve existing system-controlled branches. |

This inventory describes source migration decisions, not a completed native acceptance record. Verify DE/EN, 96/240 DPI, native pointer/keyboard, disabled/selected/pressed/active, High Contrast and all three connectors in the final frozen revision; owner-native visual acceptance is recorded separately.
