# CodexMeter Circular Glass and Menu-Bar Mark QA

## Comparison Targets

- Menu-bar source visual truth: `/var/folders/26/1jhmqmk9267cy_p2r59v5cd00000gn/T/TemporaryItems/NSIRD_screencaptureui_dst5oX/Screenshot 2026-07-12 at 9.32.06 PM.png`
- Minimal-ring source visual truth: `/Users/paiii/Desktop/Screenshot 2026-07-12 at 8.51.54 PM.png`
- Installed menu-bar implementation: `QA/glass-menubar/menu-bar-runtime-after.png`
- Installed circular-glass implementation: `QA/glass-menubar/widget-glass-runtime.png` and `QA/glass-menubar/widget-glass-on-desktop.png`
- Menu-bar source viewport: 241 × 198 px; focused status-bar region: 241 × 36 px
- Menu-bar implementation viewport: 660 × 84 px; focused status-bar region: 660 × 64 px at native 2× Retina scale
- Minimal-ring source viewport: 218 × 214 px
- Installed ring context capture: 370 × 370 px at native 2× Retina scale; the production panel remains 110 × 110 pt
- State: live account data, Minimal layout, English labels, dark app content behind the glass, blue macOS menu-bar tint

## Evidence

- Full and focused menu-bar comparison: `QA/glass-menubar/menu-bar-before-after-comparison.png`
- Full and focused circular-glass comparison: `QA/glass-menubar/widget-glass-comparison.png`
- Deterministic English light render: `QA/glass-menubar/widget-minimal-en-light.png`
- Deterministic Simplified Chinese dark render: `QA/glass-menubar/widget-minimal-zh-dark.png`
- Focused regions are used because the menu-bar template mark and circular glass treatment are the only changed visual surfaces.

## Findings

No actionable P0, P1, or P2 differences remain.

- Fonts and typography: quota percentage, window label, menu-bar percentage, weights, tracking, baselines, and tabular digits remain unchanged. Live percentages differ between captures because account usage refreshed during QA.
- Spacing and layout rhythm: the 84 pt ring and 110 pt transparent panel are unchanged. The glass is inset by half the 6 pt quota stroke, so it fills the center without extending beyond the ring. The menu-bar mark now occupies a true 10 pt intrinsic footprint and aligns optically with the percentage text instead of filling the menu-bar height.
- Colors and visual tokens: the quota keeps the existing semantic mint signal and quiet track. The center uses native macOS glass, adapts to light/dark content, and falls back to an opaque system background when Reduce Transparency is enabled.
- Image quality and asset fidelity: the supplied 64 × 64 px transparent template asset is preserved at full source resolution. Only its `NSImage` intrinsic point size is fixed to 10 pt, preventing `MenuBarExtra` from expanding it before SwiftUI layout. No replacement asset or code-drawn logo was introduced.
- Copy and content: `7D WINDOW` remains service-driven live content. The installed runtime capture shows the same label while the deterministic test fixture continues to exercise a five-hour window.
- Transparency: screen capture over real app content shows the region outside the ring remains fully transparent while content behind the circular center is visibly softened and darkened by native glass.

## Comparison History

1. Initial menu-bar evidence showed the 64 px template image expanding to nearly the full status-bar height despite a 10 pt SwiftUI frame (P1).
2. The template image's intrinsic AppKit point size was fixed to the shared 10 pt menu-bar token. Post-fix runtime evidence shows the glyph aligned with the percentage text and neighboring native status items.
3. The first Minimal implementation kept the ring center fully transparent. A native circular glass backdrop was added behind the ring content while preserving transparent outer corners (P2 resolved).
4. Post-fix runtime and deterministic captures confirm the circular glass, transparent canvas, light/dark adaptation, and compact menu-bar glyph.

## Interaction and Runtime Checks

- The Release app is running from `~/Applications/CodexMeter.app` in Minimal layout.
- Core Graphics reports the production panel at exactly 110 × 110 pt.
- The full Swift test suite passes: 44 tests, 0 failures, with the opt-in live account integration test skipped by default.
- Rendering tests assert transparent outer corners and an opaque accessibility/test fallback at the center.
- Brand-resource tests assert a 10 pt intrinsic menu-bar size while retaining the 64 × 64 px source representation.
- Browser and browser-console checks are not applicable to this native macOS implementation.

## Follow-up Polish

- P3: add a future automated `NSStatusItem` host integration test if macOS exposes a stable screenshot harness for menu-bar extras.

final result: passed
