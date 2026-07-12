# Changelog

All notable changes to CodexMeter are documented in this file.

## [Unreleased]

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

[Unreleased]: https://github.com/paiiiii/CodexMeter/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/paiiiii/CodexMeter/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/paiiiii/CodexMeter/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/paiiiii/CodexMeter/tree/v0.1.0
