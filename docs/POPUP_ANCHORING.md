# Main popup anchoring (LBS-132)

The main Lenovo Boot Selector popup is positioned when it opens, not continuously. Its fixed default form size remains 390 x 672, and the tray context menu is not repositioned.

## Anchor resolution order

1. On an actual `NotifyIcon.MouseClick`, capture the cursor's screen position and time in that icon event. At the subsequent popup open, use Windows UI Automation `AutomationElement.FromPoint` and walk only a bounded number of ancestors. Accept only a visible element whose accessible name identifies `Lenovo Boot Selector` and whose bounds resemble a notification icon.
2. For other openings, or when click-point discovery is unavailable, search selected shell-owned top-level UI Automation trees for a visible element with the exact notification-icon accessible name. Windows 10/11 taskbar and overflow shell classes are included. Never inspect WinForms private `NotifyIcon` fields.
3. If bounds are unavailable but this opening follows an actual icon click within 30 seconds, anchor to a small rectangle around that recorded click coordinate. This approximate anchor is intentionally limited to genuine left/right tray-icon clicks. The right-click context-menu `Open` command shares this path.
4. For first-run, drift/repair and other non-pointer openings without a discovered icon, use the **primary monitor's working area**, bottom-right with an eight-pixel inset. Do not borrow an unrelated mouse position.

UI Automation is best effort: Explorer restarts, Windows version-specific overflow UIA trees, inaccessible or unnamed elements and flyout dismissal may cause the shell lookup to fail. No discovery failure prevents the popup from opening. An overflow popup activated by a real icon click retains the click-based fallback even if the overflow flyout disappears during opening.

## Geometry and supported bounds

`Get-PopupLocationFromAnchor` is pure: it receives the selected display's screen bounds, working bounds, icon rectangle and the popup's *actual* WinForms size. It horizontally centers over the icon for bottom/top taskbars, prefers above the icon for bottom/auto-hidden taskbars and below for top taskbars, or places beside the icon for left/right taskbars. Final X/Y positions are clamped to the nearest feasible position inside the working area, including negative virtual-screen coordinates. When exact centering is impossible near an edge, edge-clamping takes precedence.

Public UI Automation reports screen-space icon bounds. WinForms screen/form coordinates can be virtualized differently on mixed-DPI configurations; this path has no unverified claim of exact physical-pixel alignment across all DPI-awareness modes. The click-point and working-area fallbacks preserve visibility under normal-sized displays. A desktop whose usable display is physically smaller than the unchanged popup dimensions cannot contain that entire popup without resizing its protected layout; that extreme case remains outside this placement-only change.

No firmware, BCD, TaskBroker, startup state, update scheduling, background refresh, menu rendering or popup deactivation behavior is modified.

## Validation and required real-desktop acceptance

The native PowerShell 5.1 `Test-UIPresentation.ps1` suite now covers ideal centering, icon reordering, edge clamping, overflow coordinates, top/left/right docks, negative virtual coordinates, scaled popup sizes, auto-hide placement and deterministic fallback. Hosted Windows tests exercise pure geometry; they cannot establish that a real Windows Explorer exposes usable UIA icon bounds.

For physical acceptance, verify on Windows 11: visible LBS icon at two notification-area positions, `^` overflow flyout icon, right-click `Open`, first-run/non-pointer opening, multi-monitor with negative X and mixed DPI, taskbar auto-hide, and the existing focus/deactivate/toggle behavior. Record whether UIA discovered the actual icon or the click-derived fallback was used; verify placement and absence of flyout-related premature hiding. If a platform-specific icon-name or scaling mismatch is found, capture native evidence before refining discovery.
