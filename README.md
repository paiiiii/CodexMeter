# CodexMeter

<p align="center">
  <img src="./Resources/AppIcon.png" width="128" height="128" alt="CodexMeter app icon">
</p>

<p align="center">
  <strong>English</strong> · <a href="./README.zh-CN.md">简体中文</a>
</p>

CodexMeter is a native, local-first macOS menu-bar companion for monitoring Codex rate limits, reset times, and daily token activity. It combines a compact SwiftUI interface with AppKit window controls, system glass materials, and smooth state transitions.

> CodexMeter is an independent community project and is not affiliated with or endorsed by OpenAI. It does not operate its own backend, but the local Codex app-server may contact OpenAI services using your existing Codex sign-in.

## Features

- Shows the remaining percentage for Codex rate-limit windows and a live 5-hour reset countdown.
- Displays the daily token activity returned by the account service.
- Supports three widget presentation modes:
  - **Always on Top** keeps the widget above regular windows across Spaces.
  - **Desktop** places it behind regular windows as a low-distraction desktop companion.
  - **Hidden** dismisses the widget until it is restored from the menu bar.
- Follows the macOS language automatically, with instant in-app overrides for English and Simplified Chinese.
- Uses native macOS glass, rounded surfaces, light/dark appearance, and reduced-motion/transparency accessibility settings.
- Lives in the menu bar without occupying the Dock (`LSUIElement`).
- Runs locally with no project-owned backend, ads, or telemetry.

## Language

CodexMeter follows your macOS language by default. Open **Settings → Language** to choose one of these options:

- **System Default**
- **English**
- **简体中文**

Changes apply immediately to the widget, menu-bar menu, Settings window, accessibility labels, dates, numbers, countdowns, and CodexMeter-generated errors. All Chinese system locales use the Simplified Chinese translation; other unsupported system languages fall back to English.

## Requirements

- macOS 14 Sonoma or later.
- Xcode 26 or a compatible Swift 6.2 toolchain.
- An installed Codex/ChatGPT desktop app, or a Codex CLI session signed in with a ChatGPT account.
- Network access when Codex requests current account usage.

You can check the CLI login state with:

```bash
codex login status
```

If your Codex version does not provide this command, run `codex` and follow its sign-in prompt.

## Install and Run

Clone the repository, build the release app, install it under `~/Applications`, and open it:

```bash
git clone https://github.com/paiiiii/CodexMeter.git
cd CodexMeter
./Scripts/install-local.sh
```

Install without opening the app:

```bash
./Scripts/install-local.sh --no-open
open "$HOME/Applications/CodexMeter.app"
```

Choose another destination with `DIST_DIR`:

```bash
DIST_DIR="$PWD/dist" ./Scripts/install-local.sh
```

Running the install script again safely replaces only the destination `CodexMeter.app` bundle.

## Data Source

CodexMeter starts the local `codex app-server` and communicates with it through JSON-RPC over stdio. After initialization, it primarily reads:

- `account/rateLimits/read` for account rate-limit windows and reset times.
- `account/usage/read` for token summaries and daily usage buckets.

Codex manages sign-in and token refresh. CodexMeter does not ask you to paste an API key, and it does not copy or save Codex authentication files. See the [OpenAI Codex app-server README](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md) for protocol details.

## Architecture

```text
SwiftUI views, localization, and animation
                    │
AppKit window and menu-bar control ── topmost, hidden, desktop levels
                    │
Observable state and timed refresh
                    │
Local codex app-server (JSON-RPC / stdio)
                    │
account/rateLimits/read + account/usage/read
```

The project is a Swift Package. The executable target owns the application lifecycle, while `CodexMeterKit` contains usage models, the app-server client, language resources, UI, and testable logic. The release script assembles the executable, `Info.plist`, AppIcon, and compiled SwiftPM resource bundle into a standard `.app`.

## Design System

CodexMeter uses **Signal & Silence**, a project-specific design system built around evidence before ornament, editorial breathing room, semantic quota states, and native macOS behavior. Its hierarchy keeps the five-hour quota decisive while token activity and longer-window context remain readable without visual noise.

- Read the human-facing [Design System](docs/DESIGN_SYSTEM.md).
- Inspect the machine-readable [design tokens](tokens.json).
- Use the [Design QA matrix](docs/DESIGN_QA.md) for visible changes.

The system intentionally retains CodexMeter's black-and-white restraint and mint identity signal; it does not copy another product's visual palette.

Regenerate the app icon from its 1024×1024 source with:

```bash
./Scripts/generate-icon.sh
```

## Build and Test

```bash
swift test
./Scripts/build-app.sh
```

The scripts automatically use `/Applications/Xcode.app/Contents/Developer` when available. The default output is `~/Applications/CodexMeter.app`, with a local ad-hoc signature when `codesign` is available.

For development:

```bash
swift run CodexMeter
```

Run the optional live account integration test only when you intentionally want to contact the installed Codex app-server:

```bash
CODEX_METER_LIVE_TESTS=1 swift test --filter LiveCodexIntegrationTests
```

## Privacy and Security

- No third-party analytics SDK, behavior tracking, or project-owned remote service is included.
- `.env`, API keys, Codex sign-in files, certificates, and common credential files are excluded from source control and app packaging.
- The app-server uses your existing Codex sign-in to request account usage from OpenAI; local deployment does not mean offline accounting.
- The UI is informational and should not be treated as a bill, invoice, or cost-audit source.
- The packaging script copies only the release executable, `Info.plist`, AppIcon, and declared SwiftPM resource bundles.

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Known Limitations

- A compatible, signed-in Codex/ChatGPT desktop app or CLI session is required.
- `account/usage/read` fields depend on the installed Codex version and account type; some versions or accounts may not return a daily token total.
- Remaining quota is derived from the service-provided usage percentage, not from a fixed token pool.
- The account service determines daily bucket boundaries, which may differ from local Mac midnight.
- Desktop mode simulates a desktop widget with AppKit window levels and Spaces behavior; it is not a WidgetKit extension and does not appear in the macOS widget gallery.
- Polling and rate-limit notifications can be briefly delayed. Treat the official Codex/OpenAI account surface as authoritative.
- The local app-server evolves with Codex and may require compatibility updates after a Codex upgrade.

## Troubleshooting

### The app does not appear in the Dock

This is expected. `Info.plist` enables `LSUIElement`, so CodexMeter is controlled from its menu-bar item and widget window.

### Codex cannot be found or the app stays disconnected

Confirm that the Codex CLI is available in `PATH`, or that the Codex/ChatGPT desktop app is installed and signed in. Then quit and reopen CodexMeter. You can also point to a custom executable with `CODEX_METER_CODEX_PATH`.

### Swift uses the Command Line Tools developer directory

The packaging scripts choose full Xcode automatically. For manual Swift commands:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
```

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Every user-facing copy change must include both English and Simplified Chinese resources.

See [CHANGELOG.md](CHANGELOG.md) for release history.

## References

- [OpenAI Codex app-server README](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)
- [Apple: Localizing package resources](https://developer.apple.com/documentation/xcode/localizing-package-resources)
- [Apple: LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)
- [Apple: NSWindow.Level.floating](https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/floating)
- [Apple: NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview)
- [Apple: WidgetKit](https://developer.apple.com/documentation/widgetkit)

## License

CodexMeter is available under the [MIT License](LICENSE).
