import Cocoa
import QuartzCore

final class HUDController {
    private var window: NSPanel?
    private var dismissTimer: Timer?
    
    init() {
        setupWindow()
    }
    
    private func setupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 46),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        
        // Translucent dark background (using alpha layer for genuine transparency)
        let backgroundView = NSView(frame: panel.contentView?.bounds ?? .zero)
        backgroundView.autoresizingMask = [.width, .height]
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 14
        backgroundView.layer?.masksToBounds = true
        backgroundView.layer?.backgroundColor = NSColor(white: 0.10, alpha: 0.65).cgColor
        backgroundView.layer?.borderWidth = 0.5
        backgroundView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
        
        // Content container
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Symbol icon
        let iconImageView = NSImageView()
        if let iconImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Copied") {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            iconImageView.image = iconImage.withSymbolConfiguration(config)
            iconImageView.contentTintColor = .white
        }
        
        // Text label
        let label = NSTextField(labelWithString: "Copied")
        label.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(label)
        
        backgroundView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor)
        ])
        
        panel.contentView = backgroundView
        self.window = panel
    }
    
    func show() {
        guard let window = self.window else { return }
        
        // Cancel existing timer and animation
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        // Center on the active screen
        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        if let screenFrame = targetScreen?.visibleFrame {
            let x = screenFrame.origin.x + (screenFrame.width - window.frame.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - window.frame.height) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.alphaValue = 1.0
        window.orderFrontRegardless()
        
        // Schedule fade out (0.90s - double the previous 0.45s)
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.90, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }
    
    private func fadeOut() {
        guard let window = self.window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            if window.alphaValue == 0.0 {
                window.orderOut(nil)
            }
        })
    }
}
