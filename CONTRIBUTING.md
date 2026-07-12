# Contributing to CodexMeter

Thanks for helping improve CodexMeter.

## Development Setup

1. Use macOS 14 or later with Xcode 26 or a compatible Swift 6.2 toolchain.
2. Fork and clone the repository.
3. Create a focused branch from `main`.
4. Run the test suite before and after your change:

   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
   ```

5. Build the release app when changing resources, packaging, or runtime UI:

   ```bash
   ./Scripts/build-app.sh
   ```

## Localization

- English is the development and repository documentation language.
- Every user-facing string must be defined in both:
  - `Sources/CodexMeterKit/Resources/en.lproj/Localizable.strings`
  - `Sources/CodexMeterKit/Resources/zh-Hans.lproj/Localizable.strings`
- Add every new key to `L10nKey` so resource-completeness tests can detect missing translations.
- Do not hard-code user-facing text in Swift views, accessibility modifiers, formatters, or errors.
- Keep dates, numbers, percentages, plurals, and countdowns tied to the selected app locale.
- Update both `README.md` and `README.zh-CN.md` when user-facing instructions change.

## Design System

- Read [Signal & Silence](docs/DESIGN_SYSTEM.md) before changing the widget, menu-bar presentation, Settings, motion, or brand assets.
- Treat [`tokens.json`](tokens.json) as the machine-readable source of truth. Update the token and its Swift representation together; do not introduce duplicate raw colors, spacing, radii, metrics, or durations in views.
- Keep layout on the 4-point spacing rhythm and use the documented 10/14/24-point radius hierarchy unless a native macOS control requires a documented exception.
- Use semantic tone roles (`healthy`, `caution`, `critical`, `live`, `cached`, and `offline`) rather than choosing colors by appearance.
- Preserve explicit Connecting, Syncing, Live, Cached, and Offline copy. Never present a cached snapshot as live.
- Keep mode and icon-control geometry stable across hover, selection, loading, and localization.
- Pair every symbol and color-coded state with localized visible or accessibility text.
- Use the documented asset role. In particular, do not place a contained app-icon tile inside the glass widget header.
- Motion must explain a state change, honor Reduce Motion, and avoid moving neighboring hit targets.
- Complete the relevant [Design QA matrix](docs/DESIGN_QA.md) rows for every visible change.

## Pull Requests

- Keep each pull request focused and explain user impact.
- Include tests for behavior changes and both supported languages where relevant.
- Include screenshots for visible UI changes.
- For visible changes, include light/dark evidence and both supported languages when copy or layout is affected; list any manual QA matrix rows that remain unverified.
- Do not commit credentials, Codex login data, generated `.app` bundles, or local build directories.
- Confirm `swift test` and `./Scripts/build-app.sh` pass before requesting review.

By participating, you agree to keep discussion constructive and respectful.
