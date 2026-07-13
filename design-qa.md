# CodexMeter Minimal Widget QA

- Source visual truth: `/Users/paiii/Desktop/Screenshot 2026-07-12 at 8.51.54 PM.png`
- Rendered implementation: `QA/minimal-mode/widget-minimal-en-light.png`
- White-composited implementation: `QA/minimal-mode/widget-minimal-en-light-on-white.png`
- Installed runtime capture: `QA/minimal-mode/widget-minimal-runtime.png` (transparent) and `QA/minimal-mode/widget-minimal-runtime-on-white.png` (comparison composite)
- Source viewport: 218 × 214 px
- Implementation viewport: 220 × 220 px (110 × 110 pt at 2× Retina scale)
- State: English, light appearance, 95% remaining in the primary rate-limit window
- Combined comparison evidence: `QA/minimal-mode/minimal-ring-comparison.png`
- Focused comparison: the supplied source is already a focused crop of the ring component, so the combined full comparison is also the focused comparison

## Findings

No actionable P0, P1, or P2 visual differences remain.

- Geometry: the final 84 pt ring matches the reference diameter and stays centered in a compact 110 pt transparent canvas.
- Content hierarchy: only the circular progress indicator, percentage, and window label remain. Header, token activity, secondary quota, and controls are absent.
- Typography: percentage and uppercase window label preserve the existing Signal & Silence component's type roles and alignment.
- Color: the implementation keeps CodexMeter's semantic mint signal token and quiet translucent track.
- Background: the production minimal window is transparent. The white composite exists only to make comparison against the supplied light screenshot legible.
- Dynamic data: the deterministic test snapshot uses a five-hour fixture, while the installed app's runtime capture correctly shows the current `7D WINDOW` primary quota. Labels continue to follow the service-provided window duration.

## Comparison History

1. The first implementation used a 90 pt ring and appeared visibly oversized relative to the supplied crop (P2).
2. The minimal ring was changed to the shared 84 pt primary-quota token.
3. The Retina snapshot and combined comparison were regenerated. Ring diameter, center alignment, label baseline, and surrounding breathing room now match the reference without changing the full widget's established component styling.

## Interaction and Runtime Checks

- Full and Minimal layouts are independent from Always on Top, Desktop, and Hidden presentation modes.
- The full widget can be restored from the ring context menu, menu-bar menu, Settings, or an accessibility custom action.
- Window resizing preserves the top-right anchor and clamps the result to the visible screen.
- Reduce Motion switches layouts without animated resizing.
- English light and Simplified Chinese dark minimal snapshots render at exactly 220 × 220 px with transparent corners.
- The installed panel was measured through Core Graphics at exactly 110 × 110 pt and captured with its live `7D WINDOW` content.
- Browser and browser-console checks are not applicable to this native macOS implementation.

## Follow-up Polish

- P3: capture additional real-window evidence on a multi-display Mac after future window-positioning changes.

final result: passed
