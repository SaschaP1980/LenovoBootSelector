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
