# Main popup anchoring (LBS-132)

The main Lenovo Boot Selector popup is positioned when it opens, not continuously. Its **96-DPI design baseline** is 390 × 672 client pixels; that is not an invariant physical form size on a scaled or constrained monitor. The tray context menu is not repositioned by the popup-anchoring path.

## Anchor resolution order

1. On an actual `NotifyIcon.MouseClick`, capture the cursor's screen position and time in that icon event. At the subsequent popup open, use Windows UI Automation `AutomationElement.FromPoint` and walk only a bounded number of ancestors. Accept only a visible element whose accessible name identifies `Lenovo Boot Selector` and whose bounds resemble a notification icon.
2. For other openings, or when click-point discovery is unavailable, search selected shell-owned top-level UI Automation trees for a visible element with the exact notification-icon accessible name. Windows 10/11 taskbar and overflow shell classes are included. Never inspect WinForms private `NotifyIcon` fields.
3. If bounds are unavailable but this opening follows an actual icon click within 30 seconds, anchor to a small rectangle around that recorded click coordinate. This approximate anchor is intentionally limited to genuine left/right tray-icon clicks. The right-click context-menu `Open` command shares this path.
4. For first-run, drift/repair and other non-pointer openings without a discovered icon, use the **primary monitor's working area**, bottom-right with an eight-pixel inset. Do not borrow an unrelated mouse position.

UI Automation is best effort: Explorer restarts, Windows version-specific overflow UIA trees, inaccessible or unnamed elements and flyout dismissal may cause the shell lookup to fail. No discovery failure prevents the popup from opening. An overflow popup activated by a real icon click retains the click-based fallback even if the overflow flyout disappears during opening.

## Geometry and supported bounds

`Get-PopupLocationFromAnchor` is pure: it receives the selected display's screen bounds, working bounds, icon rectangle and the popup's *actual* WinForms size. It horizontally centers over the icon for bottom/top taskbars, prefers above the icon for bottom/auto-hidden taskbars and below for top taskbars, or places beside the icon for left/right taskbars. Final X/Y positions are clamped to the nearest feasible position inside the working area, including negative virtual-screen coordinates. When exact centering is impossible near an edge, edge-clamping takes precedence.

**Design, scale and viewport are distinct.** The 390 × 672 baseline is stored at 96 DPI. On opening, [`Position-Popup`](../src/UI/Popup.ps1) resolves the target screen and effective monitor scale, calls [`Set-PopupDpiLayoutScale`](../src/UI/PopupDpiLayout.ps1), then calls `Set-PopupViewportForWorkingArea` **before** measuring the popup's actual size for anchor placement. The scaled design client size is `round(390 × scale)` by `round(672 × scale)`; the working-area-limited client viewport is the smaller of that scaled size and `max(200, working-area dimension − 12)` for each dimension. When constrained, `PopupRoot.AutoScroll` and `AutoScrollMinSize` expose the full scaled layout instead of pretending that the entire design fits; when space is restored, scrolling is disabled and the full client viewport returns. The bounded 200-pixel fallback is not a promise that the form fits displays smaller than this minimum or under nonstandard window chrome/scaling.

Manage Entries also has a mode-dependent list viewport: [`Test-LBS157-ManageViewport.ps1`](../tests/Test-LBS157-ManageViewport.ps1) covers its 34-design-pixel expansion, footer clearance and reversible normal layout. [`Test-PopupDpiLayout.ps1`](../tests/Test-PopupDpiLayout.ps1) covers actual WinForms scale/clip/scroll behavior, including synthetic 100%/250% cases and a short working area. These hosted tests do not constitute universal mixed-DPI certification or physical multi-monitor acceptance.

Public UI Automation reports screen-space icon bounds. WinForms screen/form coordinates can be virtualized differently on mixed-DPI configurations; this path has no unverified claim of exact physical-pixel alignment across all DPI-awareness modes. Click-point and working-area fallbacks remain best effort. Anchor selection and edge clamping use the **actual** post-scaling, post-viewport form size; extremely small/nonstandard displays may still require scrolling or lack room to display the popup completely.

No firmware, BCD, TaskBroker, startup state, update scheduling, background refresh, menu rendering or popup deactivation behavior is modified.

## Validation and required real-desktop acceptance

The native PowerShell 5.1 `Test-UIPresentation.ps1` suite covers centering, icon reordering, edge clamping, overflow coordinates, taskbar docking, negative virtual coordinates, scaled sizes, auto-hide placement and deterministic fallback. `Test-PopupDpiLayout.ps1` and `Test-LBS157-ManageViewport.ps1` additionally exercise real WinForms scale/viewport controls and Manage Entries layout on hosted Windows. These tests cannot establish that a real Windows Explorer exposes usable UIA icon bounds or that every mixed-DPI desktop behaves identically.

For physical acceptance, verify on Windows 11: visible LBS icon at two notification-area positions, `^` overflow flyout icon, right-click `Open`, first-run/non-pointer opening, multi-monitor with negative X and mixed DPI, taskbar auto-hide, and the existing focus/deactivate/toggle behavior. Record whether UIA discovered the actual icon or the click-derived fallback was used; verify placement and absence of flyout-related premature hiding. If a platform-specific icon-name or scaling mismatch is found, capture native evidence before refining discovery.
