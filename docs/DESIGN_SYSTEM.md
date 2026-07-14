# CodexMeter Design System

## Signal & Silence

Signal & Silence is the visual and interaction system for CodexMeter. It turns account usage data into a calm, glanceable macOS companion: the signal is the information that changes a decision; the silence is everything the interface deliberately leaves out.

The system adapts an evidence-led design methodology to a native developer tool. It does not reuse another product's palette, typography, imagery, or brand expression. CodexMeter remains black-and-white at its core, with one restrained mint signal and semantic warning colors.

The machine-readable source of truth is [`tokens.json`](../tokens.json). This document explains how to apply those tokens.

## Principles

1. **Evidence before ornament.** Usage percentage, reset time, token activity, and connection freshness must remain legible before glass, glow, or animation is added.
2. **Premium restraint.** Use fewer surfaces, colors, and effects. A single clear accent is more valuable than several decorative highlights.
3. **Editorial breath.** Negative space separates ideas and establishes rhythm. Do not fill empty space merely because it exists.
4. **Turn quota into actionable rhythm.** The interface should help someone decide whether to continue, pace work, or wait for reset—not merely report numbers.
5. **Typography is data architecture.** Size, weight, and numeral style communicate hierarchy before labels do.
6. **Visualize the mechanism.** Rings and bars represent a bounded quota. Countdowns represent time. Do not use an arbitrary chart where a direct value is clearer.
7. **Motion is feedback.** Animation explains refresh, selection, and state change. It never competes with the data.
8. **Name uncertainty.** Cached and offline data are explicitly labeled. A previously successful snapshot must never look live after the connection fails.
9. **Be native to macOS.** Adopt system materials, semantic colors, keyboard behavior, accessibility settings, and window conventions instead of imitating a web dashboard.

## Information Hierarchy

CodexMeter uses a stable three-level hierarchy:

1. **Primary:** the five-hour quota window and its remaining percentage.
2. **Secondary:** today's token activity and exact supporting value.
3. **Context:** weekly quota, reset timing, connection freshness, and window controls.

The five-hour quota gets the strongest size and position because it is usually the most immediate constraint. Secondary metrics support the decision without competing with it. If a value is unavailable, preserve the hierarchy and show an explicit placeholder or state label—do not collapse the layout.

## Foundations

### Color

Color is semantic, never decorative:

| Role | Meaning | Use |
| --- | --- | --- |
| Primary text | Current, decisive information | Hero values and essential labels |
| Secondary text | Supporting context | Metadata, exact values, reset details |
| Signal / healthy | Identity, live status, ample remaining quota | Brand glyph, live indicator, healthy quota |
| Caution | Limited quota or cached snapshot | 21–50% remaining; stale but usable data |
| Critical | Immediate constraint or offline failure | 0–20% remaining; no current data connection |
| Neutral | Connecting, syncing, or unavailable | Transitional states and tracks |

Use semantic system colors for text and native material adaptation. Never encode state with opacity alone. All status colors require a text label, symbol, or both.

### Typography

CodexMeter uses Apple system fonts only. This preserves native rendering, Dynamic Type behavior where available, and consistent localization.

| Role | Token | Treatment |
| --- | --- | --- |
| Hero activity | `typography.size.hero` | Rounded, medium, tabular numerals |
| Quota value | `typography.size.quota` | Rounded, semibold, tabular numerals |
| Body | `typography.size.body` | System regular/medium |
| Metadata | `typography.size.metadata` | Monospaced, regular, tabular numerals |
| Label / brand | `typography.size.label` / `brand` | Semibold; short copy only |

Do not introduce a third type family. Avoid uppercase for sentences; reserve compact uppercase treatment for stable micro-labels where localization remains readable.

Ten points is the minimum for compact widget labels and metadata. Ordinary body copy uses 11 points or larger; Settings should prefer native control and text styles rather than forcing compact widget sizing into a full window.

### Spacing and Shape

All layout follows a 4-point rhythm: 4, 8, 12, 16, and 24 points. A new spacing value requires a documented optical or platform reason.

Radii communicate containment:

- **10 pt — control:** buttons, status pills, and compact segments.
- **14 pt — panel:** inset quota or status groups.
- **24 pt — surface:** the outer widget silhouette.

Do not nest multiple rounded containers unless each level represents a real information group. Avoid placing an app-icon tile inside another rounded header surface.

### Material and Depth

The outer widget uses a native macOS material with one subtle border. Inset surfaces use a quiet tonal separation, not a second heavy glass effect. At most one low-amplitude mint ambient signal may sit behind content; avoid competing color glows and glossy white sweeps.

When Reduce Transparency is enabled, replace translucent material with an opaque system background and preserve the same hierarchy and border contrast.

### Motion

All transitions share the standard `0.22, 1, 0.36, 1` curve.

| Token | Duration | Purpose |
| --- | ---: | --- |
| `fast` | 0.16 s | Hover, press, compact control response |
| `standard` | 0.24 s | Selection and surface state change |
| `layoutMorph` | 0.38 s | Full-panel contraction into the primary quota ring and reverse expansion |
| `data` | 0.42 s | Quota and metric value transition |
| `refresh` | 0.85 s | One refresh rotation |

Animation must not resize a control or move a neighboring hit target. Persistent decorative animation is not permitted: the settled widget must reach an idle render state. With Reduce Motion enabled, transitions become immediate and bounded rotation is disabled.

## Components

### Widget Surface

- Full design canvas: 348 × 238 pt.
- Minimal design canvas: 110 × 110 pt, with an 84 pt primary quota ring centered on a transparent window and native circular glass behind the ring content.
- Outer radius: 24 pt; content inset: 16 pt.
- Keeps its information hierarchy in floating, desktop, and restored states.
- Uses an opaque fallback for reduced transparency and sufficient contrast in light and dark appearances.
- Minimal layout removes the surface, header, token activity, secondary quota, and controls. The full layout can be restored from the ring context menu, menu bar, Settings, or its accessibility action.
- Full/Minimal transitions keep one persistent quota ring at a fixed screen position. The glass outline interpolates from the 338 × 228 pt surface to a 78 pt circle while details scale toward the ring and fade; Reduce Motion switches immediately.
- Floating system-window shadow is disabled during the morph and in Minimal layout. Minimal depth comes only from a soft shadow on the inner glass, avoiding a hard fringe around the quota stroke.

### Brand Header

- Uses the transparent 20 pt CodexMeter glyph next to the wordmark.
- Displays connection freshness as a compact, readable status—not as color alone.
- Avoids a separate square or rounded tile behind the glyph.

### Primary Quota Ring

- Diameter: 84 pt.
- Shows one remaining percentage and one unambiguous window label.
- Uses a single semantic progress tone; the track remains quiet.
- Reset timing belongs in adjacent metadata when placing it inside the ring would crowd the value.

### Token Activity

- Uses the largest numeric role for the glanceable value.
- Keeps the exact value in a monospaced supporting line when abbreviation is used.
- Aligns tabular numerals to prevent width jitter during updates.

### Secondary Quota Panel

- Uses an inset surface and a linear bounded-progress treatment.
- Applies the same severity mapping as the primary quota.
- Never implies availability when the service did not return the window.

### Status Pill

Every runtime state has visible copy:

| State | Tone | Meaning |
| --- | --- | --- |
| Connecting | Neutral | No snapshot has been obtained yet |
| Syncing | Neutral / signal | A refresh is actively in progress |
| Live | Signal | The displayed snapshot is current |
| Cached | Caution | The last successful snapshot remains visible after a refresh failure |
| Offline | Critical | No usable snapshot is available |

### Mode Control and Icon Actions

- Mode segments and icon buttons use a stable 28 pt visual frame.
- Hover and selection may change tone, border, or label visibility only when the surrounding layout does not move.
- Every symbol has a tooltip and localized accessibility label. Persistent mode choices use a visible selected state.

### Settings

Settings remain a native macOS form rather than a miniature copy of the widget. Use system controls, semantic status feedback, flexible minimum/ideal sizing, and the same terminology as the menu and widget.

## Asset Roles

| Asset | Role | Rules |
| --- | --- | --- |
| `Resources/AppIcon.png` / `AppIcon.icns` | Installed application identity | Packaging, Finder, alerts, and About contexts; never shrink into the widget header |
| `Sources/CodexMeterKit/Resources/CodexMeterMenuBarMark.png` | Transparent glyph master | Render at 20 pt in both the widget and macOS menu bar; force the menu-bar template's intrinsic point size so AppKit cannot expand the 64 px source |
| `Sources/CodexMeterKit/Resources/CodexMeterMark.png` | Contained legacy mark | Use only where an intentional app-icon-like container is required; do not nest it inside glass or another rounded tile |

Keep transparent bounds tight enough for optical alignment. Verify the menu-bar rendering independently because template tinting may remove the glyph's source colors.

## Accessibility and Localization

- Treat Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver, keyboard navigation, light/dark appearance, and display scaling as design inputs.
- Do not communicate quota severity or connection state using color alone.
- Keep supporting text at 10–11 pt or larger and validate contrast over the real material, not a flat mockup.
- Use localized strings for all visible copy, tooltips, accessibility labels, errors, and date/time formatting.
- English and Simplified Chinese must ship together. Test layout with both; do not rely on English string length.
- Prefer full spoken accessibility values such as “55 percent remaining in the five-hour window” over concatenated visual fragments.

## Token Governance

- Swift code consumes semantic roles; it must not duplicate raw hex values, spacing constants, radii, or animation durations.
- Add or modify a value in [`tokens.json`](../tokens.json) and its Swift representation in the same pull request.
- A new token must solve a repeated product need and include a description. One-off decoration is not a token category.
- If a platform behavior requires a local exception, document it beside the component and in the pull request.
- Review visible changes against [`DESIGN_QA.md`](DESIGN_QA.md).
