import Cocoa
import QuartzCore

final class HUDController {
    private var window: NSPanel?
    private var dismissTimer: Timer?
    private let visibilityAnimationKey = "ClipAlert.hud.visibility"
    private var presentationGeneration: UInt64 = 0
    
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
    
    func show(flash: Bool = false) {
        guard let window = self.window else { return }
        
        let shouldFlash = window.isVisible || flash
        presentationGeneration &+= 1
        let generation = presentationGeneration
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        let contentLayer = window.contentView?.layer
        contentLayer?.removeAnimation(forKey: visibilityAnimationKey)
        contentLayer?.opacity = 1.0
        
        // Center on the active screen
        let targetScreen = NSScreen.main ?? NSScreen.screens.first
        if let screenFrame = targetScreen?.visibleFrame {
            let x = screenFrame.origin.x + (screenFrame.width - window.frame.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - window.frame.height) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.orderFrontRegardless()
        if shouldFlash, let contentLayer = contentLayer {
            let flash = CAKeyframeAnimation(keyPath: "opacity")
            flash.values = [1.0, 0.25, 1.0]
            flash.keyTimes = [0.0, 0.5, 1.0]
            flash.duration = 0.24
            contentLayer.add(flash, forKey: visibilityAnimationKey)
        }
        
        // Restart the dismissal timer after every copy activation.
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.90, repeats: false) { [weak self] _ in
            guard let self = self, self.presentationGeneration == generation else { return }
            self.fadeOut(generation: generation)
        }
    }
    
    private func fadeOut(generation: UInt64) {
        guard presentationGeneration == generation,
              let window = self.window,
              let contentLayer = window.contentView?.layer else { return }
        
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = contentLayer.presentation()?.opacity ?? contentLayer.opacity
        fade.toValue = 0.0
        fade.duration = 0.25
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak window, weak contentLayer] in
            guard let self = self,
                  self.presentationGeneration == generation,
                  let window = window,
                  let contentLayer = contentLayer else { return }
            window.orderOut(nil)
            contentLayer.removeAnimation(forKey: self.visibilityAnimationKey)
            contentLayer.opacity = 1.0
        }
        contentLayer.opacity = 0.0
        contentLayer.add(fade, forKey: visibilityAnimationKey)
        CATransaction.commit()
    }
}
