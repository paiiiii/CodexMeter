# CodexMeter Design QA

This checklist verifies that Signal & Silence remains readable, native, and truthful across macOS environments. Automated tests protect token and state contracts; visual and assistive-technology behavior still requires a person on a Mac.

## Automated Gates

Run before every UI pull request:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./Scripts/build-app.sh
```

The automated suite should cover:

- token invariants: positive dimensions, 4-point spacing rhythm, increasing radii, and expected widget/component metrics;
- quota severity boundaries: unavailable, critical (0–20%), caution (21–50%), and healthy (51–100%), including clamped out-of-range input;
- reduced-motion policy: zero-duration state changes and no continuous motion;
- localized key completeness for English and Simplified Chinese;
- format-placeholder parity between localizations;
- accessibility labels for icon-only controls and metric summaries;
- state mapping for Connecting, Syncing, Live, Cached, and Offline.
- settled Full, Minimal, Desktop, and Hidden states contain no perpetual animation or continuously invalidated invisible subtree.

An image-rendering smoke test may catch crashes or missing resources, but it cannot prove material contrast, correct window levels, text legibility, or crop safety.

## Manual Environment Matrix

Record evidence for every row affected by a change:

| Environment | Widget | Menu bar | Settings | Required checks |
| --- | :---: | :---: | :---: | --- |
| macOS 14, light | ✓ | ✓ | ✓ | Material fallback, contrast, window behavior |
| macOS 14, dark | ✓ | ✓ | ✓ | Borders, tracks, semantic tones |
| Current macOS, light | ✓ | ✓ | ✓ | Native material and animation behavior |
| Current macOS, dark | ✓ | ✓ | ✓ | Native material and animation behavior |
| Reduce Transparency | ✓ | — | ✓ | Opaque fallback, no lost grouping |
| Reduce Motion | ✓ | ✓ | ✓ | No pulse/rotation; no delayed meaning |
| Increase Contrast | ✓ | ✓ | ✓ | Text, selected states, and control boundaries |
| VoiceOver + keyboard | ✓ | ✓ | ✓ | Order, names, values, actions, focus visibility |
| 2× display scale / zoom | ✓ | ✓ | ✓ | Sharp assets, no clipping, stable layout |
| English | ✓ | ✓ | ✓ | Copy, number/date formatting, truncation |
| Simplified Chinese | ✓ | ✓ | ✓ | Copy, number/date formatting, truncation |

For energy-sensitive changes, profile a Release build after data has settled. Sample both Full and Minimal layouts for at least ten seconds; sustained idle CPU should remain near zero, and the local `codex app-server` should be sleeping between refreshes.

Test the menu-bar glyph on both light and dark menu-bar backgrounds and with system accent changes. Screen Recording permission may be required to collect reliable menu-bar and Spaces evidence.

## Runtime State Matrix

| Scenario | Expected state | Data presentation | Visual requirement |
| --- | --- | --- | --- |
| Launch before first response | Connecting | Stable placeholders | Neutral, explicit label; no fake values |
| Manual or timed refresh | Syncing | Keep last valid snapshot if available | Bounded refresh feedback; controls stay fixed |
| Successful response | Live | Current snapshot | Signal tone plus visible “Live” copy |
| Refresh fails after success | Cached | Preserve last successful snapshot | Caution tone, “Cached” copy, error available in detail |
| Refresh fails without snapshot | Offline | Unavailable placeholders | Critical tone, explicit “Offline” copy |
| 51–100% remaining | Healthy | Current percentage | Signal/healthy tone |
| 21–50% remaining | Caution | Current percentage | Amber tone plus readable numeric value |
| 0–20% remaining | Critical | Current percentage | Critical tone plus readable numeric value |

## Visual Review

- The five-hour quota is the first metric noticed; today's tokens are clearly secondary and weekly/context information is tertiary.
- The header glyph has no accidental square, nested tile, or oversized transparent padding.
- Only one restrained identity signal is present. There is no competing ambient glow or glossy sweep.
- Quota ring, linear quota bar, menu status, and Settings use the same severity/state meaning.
- Exact values use tabular numerals and do not visibly jitter during refresh.
- Cached data cannot be mistaken for live data.
- Hovering or selecting a mode does not move neighboring controls.
- Icon controls retain at least a stable 28 pt frame and show localized help/accessibility names.
- No text falls below the documented type roles or loses contrast over glass.
- Empty space reads as intentional separation, not unfinished layout.

## Window and Spaces Review

- **Always on Top:** stays above regular windows and behaves consistently across Spaces.
- **Desktop:** remains behind regular windows without disappearing behind the desktop layer.
- **Hidden:** removes the widget cleanly and restores it from the menu bar without duplicate windows.
- Settings activation does not unexpectedly change the saved widget mode or level.
- Quit/relaunch restores the intended mode and a sensible on-screen position.

## Release Evidence

For a visible UI change, attach:

- light and dark widget screenshots;
- English and Simplified Chinese screenshots when copy or layout changed;
- menu-bar close-up when glyph or status rendering changed;
- a short reduced-motion note or recording when animation changed;
- a concise list of matrix rows manually checked and any known limitations.

Do not mark material contrast, VoiceOver order, Spaces behavior, or menu-bar tint as verified solely from unit tests or a headless renderer.
