# CodexMeter Status Bar Brand QA

- Source visual truth: `/Users/paiii/Desktop/Screenshot 2026-07-11 at 9.29.06 PM.png`
- Implementation screenshot: `QA/menu-bar-badge-after.png`
- Viewport: source status-bar crop 64×36 px; production badge rendered at native 2× scale, 107×44 px, then normalized for comparison
- State: normal account state with `19%` remaining; macOS light/tinted menu bar appearance
- Full-view comparison evidence: `QA/menu-bar-brand-comparison.png` (old badge on the left, new badge on the right)
- Focused region comparison: the full target is already a focused status-bar component, so no smaller crop was needed

## Findings

No actionable P0, P1, or P2 differences remain for the requested status-bar icon change.

- Fonts and typography: the system menu-bar font, `19%` content, monospaced digits, baseline, weight, and antialiasing are unchanged.
- Spacing and layout rhythm: the new 14 pt mark plus 3 pt stack spacing produces about 4 pt of visible separation, matching the supplied screenshot without manual offsets.
- Colors and visual tokens: the mark renders as a native template image, so it follows light, dark, tinted, and highlighted menu-bar foreground colors.
- Image quality and asset fidelity: the old generic hex-grid SF Symbol is replaced by a dedicated transparent 64×64 optical crop of the CodexMeter C-ring. Its visible alpha bounds fill at least 50×50 px, preserving the opening, dot, and cutout ticks at status-bar size.
- Copy and content: the percentage and error-state text are unchanged. The warning triangle remains reserved for refresh errors.

## Comparison History

1. Initial evidence showed the old `circle.hexagongrid.fill` glyph next to `19%`, which did not match the new CodexMeter identity.
2. The shared brand component was moved into the Brand module, given widget/color and menu-bar/template styles, and connected to `MenuBarLabel`.
3. A tighter 64×64 menu-bar asset was added because the 128×128 widget mark had too much transparent padding at 14 pt. The final normalized comparison shows the new C-ring at the same visual size and spacing as the old icon.

## Interaction and Runtime Checks

- The production `MenuBarBadge` rendered successfully at native 2× status-bar scale.
- Independent template and color `NSImage` instances prevent menu-bar tinting from changing the in-widget color logo.
- The Release app launched with live Codex usage and retained its accessible outer label/value.
- This is a native macOS component; browser and browser-console checks are not applicable.

## Follow-up Polish

- P3: capture an additional native dark-menu-bar screenshot if a future visual refresh changes the mark or system tint behavior.

final result: passed
