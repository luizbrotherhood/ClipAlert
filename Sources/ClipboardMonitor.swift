import Cocoa
import ApplicationServices

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }
    
    let monitor = Unmanaged<ClipboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
    
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        monitor.reEnableTap()
        return Unmanaged.passRetained(event)
    }
    
    if type == .keyDown {
        monitor.handleKeyDown(event: event)
    }
    
    return Unmanaged.passRetained(event)
}

final class ClipboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pasteboardTimer: Timer?
    private var lastChangeCount: Int
    private var lastTriggerTime: TimeInterval = 0
    
    var onCopyDetected: (() -> Void)?
    
    var isAccessibilityGranted: Bool {
        if eventTap != nil {
            return true
        }
        return AXIsProcessTrusted()
    }
    
    var isKeyboardMonitoringActive: Bool {
        return eventTap != nil
    }
    
    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }
    
    func start() {
        startPasteboardMonitoring()
        startKeyboardMonitoring()
    }
    
    func stop() {
        pasteboardTimer?.invalidate()
        pasteboardTimer = nil
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
    }
    
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        if !isAccessibilityGranted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func checkAndRestartKeyboardMonitoringIfNeeded() {
        if eventTap == nil {
            startKeyboardMonitoring()
        }
    }
    
    func reEnableTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
    
    private func startKeyboardMonitoring() {
        guard eventTap == nil else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: selfPointer
        ) else {
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    func handleKeyDown(event: CGEvent) {
        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        
        let flags = nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandPressed = flags.contains(.command) && !flags.contains(.control) && !flags.contains(.option)
        
        // Keycode 8 corresponds to 'c' on standard QWERTY and ABNT2 keyboards
        let isKeyC = nsEvent.keyCode == 8 || nsEvent.charactersIgnoringModifiers?.lowercased() == "c"
        
        if isCommandPressed && isKeyC {
            notifyCopy()
        }
    }
    
    private func startPasteboardMonitoring() {
        pasteboardTimer?.invalidate()
        pasteboardTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentCount = NSPasteboard.general.changeCount
            if currentCount != self.lastChangeCount {
                self.lastChangeCount = currentCount
                self.notifyCopy()
            }
        }
    }
    
    private func notifyCopy() {
        let now = Date().timeIntervalSince1970
        // Prevent duplicate trigger within 250ms when both key event and pasteboard change fire
        if now - lastTriggerTime > 0.25 {
            lastTriggerTime = now
            DispatchQueue.main.async { [weak self] in
                self?.onCopyDetected?()
            }
        }
    }
}
