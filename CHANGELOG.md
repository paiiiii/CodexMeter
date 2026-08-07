# Changelog

All notable changes to CodexMeter are documented in this file.

## [Unreleased]

### Added

- An independent Minimal widget layout that keeps only the primary quota ring and its center content.
- Restore controls for the full layout in the widget context menu, menu bar, Settings, and accessibility actions.

### Changed

- The widget window now morphs smoothly between 348 × 238 pt and 110 × 110 pt around the primary quota ring while preserving its presentation mode.
- Added layout persistence, window-geometry, localization, and Retina rendering coverage for the Minimal layout.
- Added a circular native-glass backdrop inside the Minimal quota ring while keeping the surrounding window transparent.
- Fixed the menu-bar template image's intrinsic point size so its 64 px source cannot expand to fill the status-bar height.
- Replaced the full/minimal view swap with one persistent quota ring and a geometry-driven glass surface, so every panel edge contracts into the ring and expands back from it.
- Removed the hard system-window shadow and redundant normal-contrast border from Minimal mode, eliminating the dark aliased fringe around the ring.
- Matched the menu-bar glyph's 20 pt optical footprint to neighboring native status items.
- Removed the perpetual Live-status pulse that kept SwiftUI rendering continuously while the widget was idle.
- Unmounted the invisible full-panel subtree after the Minimal morph completes, eliminating its hidden blur, status, and countdown work.
- Limited refresh feedback to one bounded rotation, avoided snapshot-wide animations when only the sync timestamp changes, and added coalesced polling sleeps with offline backoff.
- Added a full-area double-click interaction to the quota ring for switching between Full and Minimal layouts in either direction.

## [0.4.0] - 2026-07-12

### Added

- The Signal & Silence design system with reusable SwiftUI foundations and components.
- Machine-readable design tokens and a macOS design QA matrix.
- Explicit Cached connection state and stable compact presentation-mode controls.
- Automated contracts for semantic quota states, connection states, motion, and design tokens.

### Changed

- Refined the widget hierarchy around the primary quota, daily token activity, and reset rhythm.
- Unified quota, status, Settings, menu-bar, accessibility, and reduced-motion/transparency behavior.
- Replaced the contained header mark with the transparent CodexMeter glyph.
- Updated application and app-server client metadata to version 0.4.0.

## [0.3.0] - 2026-07-12

### Added

- Automatic language selection based on the macOS preferred language.
- An in-app language picker with System Default, English, and Simplified Chinese options.
- English and Simplified Chinese resources for the widget, menu bar, Settings, accessibility, formatting, and app-generated errors.
- Localization resource, preference persistence, pluralization, formatting, and live error relocalization tests.

### Changed

- Made English the default app and repository documentation language.
- Added a dedicated Simplified Chinese README.
- Updated application and app-server client metadata to version 0.3.0.

## [0.2.0] - 2026-07-11

### Added

- The CodexMeter app and in-widget brand mark.
- A live reset countdown for the primary five-hour quota window.
- A dedicated compact template mark for the macOS status bar.

### Changed

- Reduced the status-bar mark to a 10-point footprint for native menu-bar proportions.
- Removed the unwanted square border around the widget's upper-left brand area.

## [0.1.0] - 2026-07-11

### Added

- The initial native macOS menu-bar and desktop usage widget.
- Codex app-server integration for rate limits and daily token activity.
- Always-on-top, desktop, and hidden presentation modes.
- Local release packaging, ad-hoc signing, and automated Swift tests.

[Unreleased]: https://github.com/paiiiii/CodexMeter/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/paiiiii/CodexMeter/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/paiiiii/CodexMeter/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/paiiiii/CodexMeter/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/paiiiii/CodexMeter/tree/v0.1.0
