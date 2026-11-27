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

## LBS-270 rollout inventory (v1.10.2.0 historical implementation)

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

## Owner-approved corrective Soft Accent Hover (v1.10.2.1)

The owner observed that the shared lower edge in v1.10.2.0 is awkward on neutral framed buttons and barely visible on red confirmation buttons. The approved visual concept differentiates control roles without changing action admission or semantic state. All values below are normal-theme presentation tokens; no OS-owned High Contrast override.

| Role | Normal / hover contract |
| --- | --- |
| Neutral framed action | Configured idle fill/ink; hover surface blends 12% #FF6E66 into idle fill, full 1-design-pixel pale-red frame; no lone bottom edge. |
| Filled primary action | Existing #E1251B; hover #E12920 and full #FF6E66 frame, retain configured white/off-white ink. The proposed #F03A30 was rejected for small white-text contrast; #E12920 retains >=4.5:1 for #FCFCFC. |
| Inline action/link | Idle ink, pale-red pointer ink and 2-design-pixel text-width underline, no framed button. Applies to alias Apply/Cancel, Customize and available-update header link. |
| Row / menu / navigation | 12% hover tint and pale-red action title; existing selection, pending, hidden and keyboard focus remain distinct. No added row stripe because existing selection markers already own that position. Tray keyboard-selected background and active modal navigation highlight remain unchanged. |
| Icon | Pale-red pointer glyph plus 31/255-alpha circular halo within existing hit target; no halo for disabled, active-operation/modal relationship, drag or keyboard-only cue. |
| Segmented selection | Unselected hover tint and frame; selected fill and existing selection border remain, inner hover frame distinct. |
| Switch | Existing on/off fill and pale-red track contour; shared label/toggle tint, separate focus perimeter. |
| Startup recovery | Native framed tint with independent fallback tokens, even if embedded WinForms types cannot initialize. |

Pressed states, actual focus cues, action guards, status dots, existing active side-popup connectors (#E1251B), native ownership and all product safety boundaries are retained. The corrected visual contract requires native qualification and physical owner acceptance before Issue closure.

## Owner-approved semantic status family (LBS-274, 2026-11-27)

The owner approved the six-symbol visual proposal and explicitly authorized implementation. This semantic palette is separate from LBS-270 action, selection and connector ink.

| State | Ink | Geometry (32-unit reference) |
| --- | --- | --- |
| Success | `#81B895` | Circle centered at (16,16), radius 13; check (9.5,16), (14,20.5), (22.5,11.5). |
| Warning | `#EAB65E` | Rounded outlined triangle; vertical exclamation and round dot. |
| Error | `#F05D55` | Same circle; diagonal cross (11,11) to (21,21) and converse. |
| Information | `#78A9E3` | Same circle; lowercase i, vertical stem and round dot. |
| Busy | `#B8C2CE` | Same circle, 22% alpha track and 270-degree open arc with round caps; static, no animation/timer. |
| Unknown | `#999999` | Same circle; curved question mark and round dot. |

Size classes at 96 DPI: Small 16 x 16 / 1.5 px stroke, Medium 24 x 24 / 2 px, Large 40 x 40 / 3 px. Scale once with the layout owner's physical bounds; never multiply font points by DPI. Use anti-aliased GDI+ geometry, rounded caps/joins, centered square, proportional strokes and bounded drawing. In High Contrast use system WindowText on Window, omit the low-opacity Busy track, and retain every distinct shape. The accompanying localized status text and accessible name/description remain authoritative. No new status claims or active operations are inferred from the icon.

Design approval is not native rendering acceptance. Qualification and complete rollout remain separate from this reference.

### Status-symbol inventory and migration boundaries

| Owner / surface | Previous symbol / state | LBS-274 mapping |
| --- | --- | --- |
| Dialogs: regular notice, including update, diagnostics, preference and maintenance results | check, X, exclamation, i | Success, Error, Warning, Info according to existing Kind; Medium. Never infer success from a button or title. |
| Dialogs: inline diagnostic copy feedback | Localized Copied check and colored success/failure text | Small Success or Warning within the existing native copy button; reserve the icon slot in dialog layout, retain repeat-copy action and existing two-second restoration timer. No new timer or image cache. |
| Dialogs: restart confirmation and removal | exclamation | Warning, Medium; decisions unchanged. |
| Dialogs: setup, repair, migration, reinitialize confirmation | i or plus | Info, Medium; preserve confirmation severity and admission. |
| System Status: summary, readiness, drift | check, exclamation, ellipsis, question mark | Success / Warning / Busy / Unknown according to existing state projection; Small. Unknown is neutral gray, not confirmed attention or error. Align to first value line, not wrapped secondary details. Other target/time rows remain text. |
| Maintenance state panel | gear, exclamation, plus, ellipsis | SetupRequired and RepairRequired Warning; Unknown Unknown; ReinitializeRequired Info; ongoing maintenance Busy. Large. Existing visibility/readiness and button decisions remain unchanged. |
| Normal boot row | pending ellipsis, selected check, idle empty | Pending Busy Small, existing pending caption, marker and accessible hint retained. Selected check remains a selection mark (not verified global success), idle remains empty. |
| Startup recovery | red exclamation badge | Error or Info for already-running notice, Medium, when native assembly available. If assembly initialization failed, retain independent legacy native badge and final Windows MessageBox fallback: recovery cannot depend on the failing assembly. |
| Main header refresh/info/update, tray navigation, management eye/grip/pencil/clear, close, switches | action/interaction marks | Excluded. Refresh animation/operation ink belongs to action control, header Info is not the semantic Info icon, update link and status captions retain their existing behavior. |
| Boot type dots, default picker selection/clear, normal and Manage selection/visibility marks, language flags, OS window/application icons | identity, selection, navigation, application branding | Excluded. Keep existing color, selection and tooltips. |
| Plain localized status text (header, footer, pending/default/readiness captions, diagnostics/update/refresh, timestamps) | text without a status symbol | Retain authoritative text; no fabricated status or new icon-dependent action. |
| Native file choosers, OS error dialogs and shell notifications | OS-controlled | Excluded from custom rendering; preserve system accessibility and recovery. |

Implementation uses one non-selectable Label-derived native status control. Existing localized message, value, heading and tooltip content supplies accessible semantics. The opt-in copy action draws the same Small renderer in a reserved right-hand slot without replacing its native Button. No polling, animation, firmware reads/writes or new dependencies. This source inventory is subject to final ownership/contract sweep and native qualification.
