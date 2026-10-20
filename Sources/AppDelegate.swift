import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let hudController = HUDController()
    private let clipboardMonitor = ClipboardMonitor()
    
    private let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

    private let defaultsKeyVisual = "visualFeedbackEnabled"
    private let defaultsKeySound = "soundFeedbackEnabled"
    private let defaultsKeySoundName = "soundName"
    
    private let availableSounds = ["Tink", "Pop", "Bottle", "Purr", "Ping"]
    private var alertSound: NSSound?
    private var alertSoundName: String?
    
    var isVisualFeedbackEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: defaultsKeyVisual) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: defaultsKeyVisual)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKeyVisual)
        }
    }
    
    var isSoundFeedbackEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: defaultsKeySound) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: defaultsKeySound)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKeySound)
        }
    }
    
    var selectedSoundName: String {
        get {
            return UserDefaults.standard.string(forKey: defaultsKeySoundName) ?? "Tink"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKeySoundName)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupClipboardMonitor()
        
        // Prompt for accessibility if not yet granted
        if !clipboardMonitor.isAccessibilityGranted {
            clipboardMonitor.requestAccessibility()
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipAlert") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.title = "📋"
            }
        }
        
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        buildMenu(menu)
    }
    
    private func setupClipboardMonitor() {
        clipboardMonitor.onCopyDetected = { [weak self] in
            self?.handleCopyDetected()
        }
        clipboardMonitor.start()
    }
    
    private func handleCopyDetected() {
        if isVisualFeedbackEnabled {
            hudController.show(flash: alertSound?.isPlaying ?? false)
        }
        if isSoundFeedbackEnabled {
            playAlertSound(name: selectedSoundName)
        }
    }
    
    private func playAlertSound(name: String) {
        if alertSoundName != name {
            alertSound?.stop()
            alertSound = NSSound(named: NSSound.Name(name))
            alertSoundName = name
        }
        
        guard let sound = alertSound else { return }
        sound.stop()
        sound.currentTime = 0
        sound.play()
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        clipboardMonitor.checkAndRestartKeyboardMonitoringIfNeeded()
        buildMenu(menu)
    }
    
    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        
        // Title header
        let headerItem = NSMenuItem(title: "ClipAlert (v\(appVersion))", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Visual alert toggle
        let visualItem = NSMenuItem(title: "Visual Alert (HUD)", action: #selector(toggleVisualAlert(_:)), keyEquivalent: "")
        visualItem.target = self
        visualItem.state = isVisualFeedbackEnabled ? .on : .off
        menu.addItem(visualItem)
        
        // Sound alert toggle
        let soundItem = NSMenuItem(title: "Sound Alert", action: #selector(toggleSoundAlert(_:)), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = isSoundFeedbackEnabled ? .on : .off
        menu.addItem(soundItem)
        
        // Sound picker submenu
        let soundMenu = NSMenu()
        for sound in availableSounds {
            let item = NSMenuItem(title: sound, action: #selector(selectSound(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sound
            item.state = (sound == selectedSoundName) ? .on : .off
            soundMenu.addItem(item)
        }
        let soundSubmenuItem = NSMenuItem(title: "Sound Effect", action: nil, keyEquivalent: "")
        soundSubmenuItem.submenu = soundMenu
        menu.addItem(soundSubmenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Test feedback item
        let testItem = NSMenuItem(title: "Test Alert", action: #selector(testAlert(_:)), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Accessibility status
        if clipboardMonitor.isKeyboardMonitoringActive || clipboardMonitor.isAccessibilityGranted {
            let accessItem = NSMenuItem(title: "✓ Accessibility Granted", action: nil, keyEquivalent: "")
            accessItem.isEnabled = false
            menu.addItem(accessItem)
        } else {
            let accessItem = NSMenuItem(title: "⚠️ Grant Accessibility Permission...", action: #selector(requestAccessibilityPermission(_:)), keyEquivalent: "")
            accessItem.target = self
            menu.addItem(accessItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(title: "Quit ClipAlert", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc private func toggleVisualAlert(_ sender: NSMenuItem) {
        isVisualFeedbackEnabled.toggle()
    }
    
    @objc private func toggleSoundAlert(_ sender: NSMenuItem) {
        isSoundFeedbackEnabled.toggle()
    }
    
    @objc private func selectSound(_ sender: NSMenuItem) {
        guard let soundName = sender.representedObject as? String else { return }
        selectedSoundName = soundName
        playAlertSound(name: soundName)
    }
    
    @objc private func testAlert(_ sender: NSMenuItem) {
        handleCopyDetected()
    }
    
    @objc private func requestAccessibilityPermission(_ sender: NSMenuItem) {
        clipboardMonitor.requestAccessibility()
    }
    
    @objc private func quitApp(_ sender: NSMenuItem) {
        clipboardMonitor.stop()
        NSApp.terminate(nil)
    }
}
