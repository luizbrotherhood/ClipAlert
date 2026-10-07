# Project Memory

> **Maintenance rule:** This file preserves chronological project context, decisions, analyses, validations, pending work, and the reasons that matter for interpreting them. Keep entries in reverse chronological order, with the newest entry immediately below this introductory rule. Edit it only when the user explicitly requests an update to `MEMORY.md`. Task completion, session end, new results, or code changes do not by themselves authorize an edit.

## 2026-10-07 — Initial ClipAlert architecture, HUD design iterations, and macOS TCC resolution

This entry records the initial architecture, design decisions, iterative visual refinements, and security/permissions resolution for the ClipAlert macOS application.

### Motivation and Core Scope

Luiz initiated the project to solve a frequent productivity friction: pressing `Cmd+C` (or intending to) without receiving visual or acoustic confirmation that the copy shortcut actually registered. This issue is particularly noticeable when copying the same text selection twice consecutively or in applications with latent UI responses.

Key requirements established from the project inception:
1. Provide subtle, non-intrusive visual and audio feedback upon clipboard modification and upon `Cmd+C` keystrokes (even if the pasteboard content does not change).
2. The application must run as a lightweight menu bar application (`NSStatusItem`) without an icon in the macOS Dock (`LSUIElement = true`).
3. Offer straightforward menu toggles to independently enable/disable visual and audio feedback.
4. The visual feedback must be a small, transparent rounded box (HUD) centered on the active screen displaying a concise message such as "Copied", rather than flashing the menu bar icon.
5. Avoid requiring a full ~30 GB Xcode IDE installation, relying instead on native Swift compilation via command-line tools.
6. The project root is `/Users/luizbrotherhood/Dropbox/ClipAlert`.

### Architecture and Technology Choices

1. **Compiler and Build Pipeline (`build.sh`)**:
   - Built with Apple Swift 5.9 on Apple Silicon (`arm64-apple-macos11.0`) using direct `swiftc` invocations against system frameworks (`Cocoa`, `ApplicationServices`, `QuartzCore`).
   - The build script automates process cleanup (`killall ClipAlert`), bundle generation (`ClipAlert.app/Contents`), `Info.plist` generation, source compilation, ad-hoc code signing (`codesign`), and execution (`./build.sh run`).
2. **Dual-Trigger Detection Engine (`ClipboardMonitor.swift`)**:
   - *Low-level event tap (`CGEventTap`)*: Intercepts `Cmd+C` system-wide using `CGEvent.tapCreate` with a `keyDown` filter. This guarantees detection even when copying identical content where pasteboard hashes do not alter. Automatically handles tap re-enabling upon timeout.
   - *Pasteboard polling (`NSPasteboard.general.changeCount`)*: A 150ms timer tracks pasteboard counter changes to catch context-menu copies (Right-Click -> Copy) and application menu commands.
   - *Debouncing*: A 250ms threshold prevents duplicate triggering when a `Cmd+C` keystroke simultaneously increments the pasteboard counter.
3. **Floating HUD Panel (`HUDController.swift`)**:
   - Implemented as a borderless, non-activating panel (`NSPanel` with `.nonactivatingPanel` and `.floating` level), preventing the HUD from stealing keyboard focus from active document editors or terminal sessions.
   - Configured with `ignoresMouseEvents = true` so user clicks pass through the HUD window uninterrupted.
   - Centers dynamically on the active display (`NSScreen.main?.visibleFrame`).
4. **Menu Bar and Preferences (`AppDelegate.swift`)**:
   - Houses the `NSStatusItem` in the system menu bar using the template SF Symbol `doc.on.clipboard`.
   - Persists user preferences (`visualFeedbackEnabled`, `soundFeedbackEnabled`, `soundName`) in `UserDefaults`.
   - Offers sound effect options (`Tink`, `Pop`, `Bottle`, `Purr`, `Ping`), an immediate "Test Alert" item, and live Accessibility status reporting.

### Visual HUD Evolution

1. **Iteration 1 (Initial Setup)**:
   - Used `NSVisualEffectView` with `.hudWindow` material and white text.
   - *Issue*: On macOS Light Mode, `NSVisualEffectView` rendered as a solid light-gray rectangular button. White text and white checkmark were virtually illegible against the light background.
2. **Iteration 2 (Contrast Enhancement)**:
   - Forced `appearance = NSAppearance(named: .vibrantDark)` and pure bold white text (`.white`, `.bold`).
   - *Issue*: High text contrast was achieved, but macOS Sequoia rendered the `.hudWindow` material as an opaque dark block, completely obscuring underlying desktop and window text.
3. **Iteration 3 (Definitive Transparency and Duration Doubling)**:
   - Replaced `NSVisualEffectView` with a direct `NSView` layer using `NSColor(white: 0.10, alpha: 0.65)` (65% opacity / 35% transparency) and a subtle 0.5pt border (`alpha: 0.25`).
   - Subview labels ("Copied") and the checkmark icon maintain 100% solid white opacity, producing genuine glass transparency while keeping text razor-sharp across both dark and light windows.
   - Doubled the visible display interval before fade-out from 0.45s to 0.90s (plus 0.25s smooth fade-out).

### macOS TCC Accessibility and Code Signing Resolution

During iterative rebuilds, the menu item displayed `⚠️ Grant Accessibility Permission...` even though the user had toggled the permission in System Settings.
- *Root Cause*: Rebuilding an unsigned binary with `swiftc` alters the code directory hash (`cdhash`). macOS Transparency, Consent, and Control (TCC) orphaned the previous permission entry. Furthermore, `AppDelegate` passively relied on `AXIsProcessTrusted()`, which caches stale state within the running process and prevented `startKeyboardMonitoring()` from being re-attempted.
- *Remediation*:
  1. Added ad-hoc code signing to `build.sh`: `codesign --force --deep --sign - "${APP_BUNDLE}"`.
  2. Updated `ClipboardMonitor.swift` and `AppDelegate.swift` to actively attempt `CGEvent.tapCreate` on every menu opening (`checkAndRestartKeyboardMonitoringIfNeeded()`), reporting `✓ Accessibility Granted` based on actual hook success (`isKeyboardMonitoringActive`).
  3. Provided `tccutil reset Accessibility com.luizbrotherhood.clipalert` to clear corrupted permission state.
