# ClipAlert

ClipAlert is a lightweight, non-intrusive macOS menu bar application designed to provide immediate visual and acoustic feedback whenever a copy operation occurs or the clipboard shortcut (`Cmd+C`) is pressed.

---

## Motivation

When working on macOS, users frequently trigger `Cmd+C` without receiving tactile or visual confirmation that the keystroke was captured, especially when copying identical text consecutively or in applications with delayed responses. ClipAlert eliminates this uncertainty by displaying a brief, translucent HUD box in the center of the active screen and playing an unobtrusive system sound whenever copy is executed.

---

## Key Features

1. **Unobtrusive Centered HUD**: A sleek, dark translucent rounded box (65% opacity) appearing in the screen center with the label "Copied" and a checkmark icon. It ignores mouse clicks (`ignoresMouseEvents = true`), does not steal application focus (`.nonactivatingPanel`), and fades out smoothly after 0.90 seconds.
2. **Dual-Trigger Detection**:
   - **Keystroke Interception (`CGEventTap`)**: Detects `Cmd+C` at the system event tap level, triggering feedback even when copying the same text repeatedly where pasteboard content remains unchanged.
   - **Pasteboard Polling (`NSPasteboard`)**: Monitors `changeCount` at 150ms intervals to catch copies initiated through context menus (Right-Click -> Copy) or application menus.
   - **Smart Debounce**: A 250ms debounce window prevents double-triggering when both the keypress and the pasteboard modification fire simultaneously.
3. **Menu Bar Controls**:
   - Independent toggles for visual HUD and sound feedback.
   - Sound effect selector (`Tink`, `Pop`, `Bottle`, `Purr`, `Ping`).
   - "Test Alert" action for instant preview.
   - Live Accessibility permission status indicator with direct shortcut to macOS System Settings.
4. **Zero-Dependency Native Architecture**:
   - Written in pure Swift using Apple frameworks (`Cocoa`, `ApplicationServices`, `QuartzCore`).
   - Configured as an agent application (`LSUIElement = true`), running exclusively in the menu bar without cluttering the macOS Dock or App Switcher.
   - Compiled directly via the Apple Swift command-line compiler (`swiftc`) without requiring the full Xcode IDE.
   - Integrated ad-hoc code signing (`codesign`) to preserve macOS TCC permissions across builds.

---

## Requirements

- macOS 11.0 (Big Sur) or newer (Apple Silicon `arm64`).
- Xcode Command Line Tools (`swiftc` installed, verified via `swift --version`).

---

## Build and Run

To compile, code-sign, and launch ClipAlert, run the build script from the project root:

```bash
cd /Users/luizbrotherhood/Dropbox/ClipAlert
./build.sh run
```

The script automatically:
1. Closes any previously running instance of ClipAlert.
2. Generates a fresh `.app` bundle structure in `build/ClipAlert.app`.
3. Creates the `Info.plist` with agent settings.
4. Compiles the Swift sources with optimizations (`-O`).
5. Signs the application bundle with an ad-hoc identity (`codesign --force --deep --sign -`).
6. Launches the application.

---

## Accessibility Permissions

Global keystroke detection (`Cmd+C`) requires macOS Accessibility permission under **System Settings > Privacy & Security > Accessibility**.

If you need to reset or refresh permissions after rebuilding:
```bash
tccutil reset Accessibility com.luizbrotherhood.clipalert
cd /Users/luizbrotherhood/Dropbox/ClipAlert && ./build.sh run
```
When prompted, enable ClipAlert in the System Settings list. The menu bar icon will confirm with `✓ Accessibility Granted`.
