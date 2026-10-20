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
    private var lastKeyboardTriggerTime: TimeInterval?
    private var lastPasteboardChangeTime: TimeInterval?
    
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
        let hasNoOtherModifiers = !flags.contains(.control) && !flags.contains(.option)
        
        // Keycode 8 corresponds to 'c' on standard QWERTY and ABNT2 keyboards.
        let isKeyC = nsEvent.keyCode == 8 || nsEvent.charactersIgnoringModifiers?.lowercased() == "c"
        
        // CGEventFlags.command combines left and right Command. Keycode 55 is the
        // physical left-Command key; checking it ignores right-Command shortcuts.
        let isLeftCommandPressed = CGEventSource.keyState(
            .combinedSessionState,
            key: 55
        )
        
        if isLeftCommandPressed && hasNoOtherModifiers && isKeyC {
            notifyCopy(isKeyboardShortcut: true)
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
    
    private func notifyCopy(isKeyboardShortcut: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        if isKeyboardShortcut {
            lastKeyboardTriggerTime = now
            DispatchQueue.main.async { [weak self] in
                self?.onCopyDetected?()
            }
            return
        }
        
        // Suppress the pasteboard update paired with a recent Cmd+C.
        let isPairedKeyboardUpdate = lastKeyboardTriggerTime.map { now - $0 <= 0.25 } ?? false
        
        // Record every observed change, including a paired keyboard update, so follow-up
        // rewrites by clipboard utilities are coalesced with the original copy.
        let isRapidPasteboardChange = lastPasteboardChangeTime.map { now - $0 <= 0.5 } ?? false
        lastPasteboardChangeTime = now
        guard !isPairedKeyboardUpdate, !isRapidPasteboardChange else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.onCopyDetected?()
        }
    }
}
