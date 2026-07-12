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

## Pull Requests

- Keep each pull request focused and explain user impact.
- Include tests for behavior changes and both supported languages where relevant.
- Include screenshots for visible UI changes.
- Do not commit credentials, Codex login data, generated `.app` bundles, or local build directories.
- Confirm `swift test` and `./Scripts/build-app.sh` pass before requesting review.

By participating, you agree to keep discussion constructive and respectful.

