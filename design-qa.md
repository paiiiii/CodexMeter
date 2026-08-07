# CodexMeter Morph, Edge, and Menu-Bar Size QA

## Comparison Targets

- Aliased-edge source truth: `/var/folders/26/1jhmqmk9267cy_p2r59v5cd00000gn/T/TemporaryItems/NSIRD_screencaptureui_b5KHd6/Screenshot 2026-07-12 at 10.06.35 PM.png`
- Undersized menu-bar source truth: `/var/folders/26/1jhmqmk9267cy_p2r59v5cd00000gn/T/TemporaryItems/NSIRD_screencaptureui_Jh2u6N/Screenshot 2026-07-12 at 10.09.23 PM.png`
- Installed Minimal window: `QA/morph-refinement/widget-minimal-window-final.png`
- Installed Minimal window in desktop context: `QA/morph-refinement/widget-minimal-context-final.png`
- Installed menu-bar implementation: `QA/morph-refinement/menu-bar-runtime.png`
- Installed shrink animation: `QA/morph-refinement/shrink-animation-final.mov`
- Edge source viewport: 272 × 254 px; installed window viewport: 220 × 220 px (110 × 110 pt at 2× Retina scale)
- Menu source viewport: 206 × 79 px; installed external-display capture: 430 × 42 px at 1× scale
- State: floating presentation, Minimal/Full transition, live seven-day quota, dark content behind native glass, blue macOS menu-bar tint

## Evidence

- Focused edge before/after: `QA/morph-refinement/edge-before-after-comparison.png`
- Focused menu-bar size before/after: `QA/morph-refinement/menu-bar-size-comparison.png`
- Full transition sequence: `QA/morph-refinement/shrink-animation-contact-sheet.png`
- Focused 20 fps transition sequence: `QA/morph-refinement/shrink-animation-detail.png`
- Deterministic midpoint render: `QA/morph-refinement/widget-morph-midpoint-en-light.png`
- English light and Simplified Chinese dark settled renders: `QA/morph-refinement/widget-minimal-en-light.png` and `QA/morph-refinement/widget-minimal-zh-dark.png`

## Findings

No actionable P0, P1, or P2 differences remain.

- Fonts and typography: percentage, quota label, token metrics, metadata, and status-bar percentage retain their established system-font roles. The persistent quota ring does not scale during the layout morph, so its type remains sharp and stable instead of being raster-scaled.
- Spacing and layout rhythm: the quota ring keeps one fixed screen-space center throughout the transition. The 338 × 228 pt full glass surface contracts continuously into a 78 pt circle inside the 84 pt ring, and expands along the exact reverse path. Full details scale toward that focal point and fade before clipping becomes visually noisy.
- Colors and visual tokens: semantic mint, quiet track, native glass, and light/dark adaptation remain unchanged. Normal-contrast Minimal glass no longer adds a redundant dark border; Increased Contrast retains a one-point semantic border.
- Image quality and edge fidelity: the hard one-pixel dark contour is absent in the installed capture. Minimal mode and transition frames disable the `NSPanel` system shadow; a soft SwiftUI shadow is applied only to the inner glass, not to the quota stroke. Progress and remaining track arcs no longer overlap underneath each other's antialiased edges.
- Icons and assets: the original 64 × 64 px transparent template master remains unchanged. Its AppKit intrinsic size and SwiftUI frame are both 20 pt, producing an optical footprint equal to the neighboring ChatGPT and `zm` status items.
- Copy and content: all live labels remain service-driven; the capture-to-capture percentage change is expected account usage, not design drift.
- Motion and interaction: the video and 20 fps sequence show the full panel edges converging on the stationary circle, with the reverse expansion verified separately. Window frame, glass shape, content opacity, and hit testing share one geometry progress. Reduce Motion bypasses the intermediate frames.

## Comparison History

1. Initial Minimal evidence showed a continuous near-black one-pixel contour outside the green ring (P1). Root cause was the floating `NSPanel` system shadow following the transparent window's quota-stroke alpha, compounded by a normal-contrast glass border. Minimal/transition system shadow and the redundant border were removed; post-fix edge evidence is clean.
2. The previous Full/Minimal implementation swapped two complete view trees and resized from the panel's top-right corner (P1). The primary quota ring jumped roughly 230 pt horizontally instead of acting as the focal point. The implementation now keeps one persistent ring, preserves its global center, and derives the glass/content morph from the live window size. Post-fix video shows continuous contraction and reverse expansion.
3. The 10 pt status-bar glyph was visibly smaller than adjacent icons (P2). It was increased to 20 pt after measuring the neighboring 28–34 px optical bounds. Post-fix capture shows matched icon scale without returning to the original 64 pt expansion bug.

## Interaction and Runtime Checks

- Menu-bar commands were used to run both Minimal → Full and Full → Minimal production transitions.
- Final Core Graphics window bounds are exactly 110 × 110 pt in Minimal mode; Full mode reaches exactly 348 × 238 pt.
- The quota center remains invariant in pure-geometry tests, including the reverse transformation.
- Controls and dragging are disabled only during the 0.38 s morph and restored on completion.
- System-window shadow policy is covered for settled floating Full, Minimal, transition, and Desktop states.
- The full Swift suite passes: 51 tests, 0 failures, with one opt-in live account test skipped by default.
- Production interaction smoke testing confirmed that a single click leaves the layout unchanged, double-clicking the full 84 pt circular hit area switches `110 × 110 → 348 × 238 → 110 × 110`, and dragging from inside the ring still moves the panel.
- Release signing, packaged resources, localization plists, design tokens, and whitespace validation pass.
- Browser and browser-console checks are not applicable to this native macOS implementation.

## Energy Regression QA — 2026-07-14

The installed Release build was sampled after account data settled, using the same Minimal + floating state reported in Activity Monitor.

| Settled state | Before | After |
| --- | ---: | ---: |
| Minimal CPU, 1 s samples | 96.5–99.4% | 0.0% across 10 samples |
| Minimal physical footprint | 92.2 MB | 24.8 MB |
| Full CPU, 1 s samples | not separately captured | 0.0% across 10 samples |
| Hidden CPU, 1 s samples | not separately captured | 0.0% across 5 samples |

- Before the fix, the main thread continuously executed `NSHostingView.layout → AnimatableAttribute → RepeatAnimation`; the local Codex app-server remained at 0.0% CPU.
- After the fix, 4,386 of 4,387 final Minimal-mode main-thread samples were blocked waiting for the next event. No `RepeatAnimation` remained.
- A final installed-build window that crossed a scheduled refresh returned immediately to idle: seven of ten one-second samples were at or below 0.1% CPU, with only three bounded refresh samples (0.8%, 1.6%, and 15.9%).
- A scheduled refresh observed during the Full-mode sample performed bounded layout work and returned to sleep; it did not restart continuous rendering.
- `powermetrics` hardware wattage was unavailable without elevated privileges, so CPU, process power, physical footprint, and symbolicated sampling are the comparison metrics.
- The original Minimal + floating preference was restored after Full and Hidden verification.

## Follow-up Polish

- P3: capture the same production morph on macOS 14 hardware to supplement the tested `.ultraThinMaterial` fallback path.

final result: passed
