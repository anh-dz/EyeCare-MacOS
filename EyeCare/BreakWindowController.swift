import AppKit
import SwiftUI

// MARK: - Custom NSWindow Subclass to Allow Becoming Key
class BreakWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - BreakWindowController
class BreakWindowController: NSWindowController {
    let timerManager: TimerManager
    var overlayView: BreakOverlayView?
    var onClose: (() -> Void)?
    private var previousAppBundleID: String?

    init(timerManager: TimerManager) {
        self.timerManager = timerManager

        // Use our custom BreakWindow so it can become key
        let window = BreakWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        window.hidesOnDeactivate = false
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = window else { return }

        // Record the currently active app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            previousAppBundleID = frontApp.bundleIdentifier
        }

        // 1) Install overlayView before animating
        if overlayView == nil {
            overlayView = BreakOverlayView(
                frame: window.contentView?.bounds ?? .zero,
                timerManager: timerManager
            )
            overlayView?.onClose = { [weak self] in
                self?.onClose?()
            }
            window.contentView = overlayView
        }

        // 2) Set up presentation options (hide menu bar, dock, etc.)
        NSApp.presentationOptions = [
            .hideMenuBar,
            .hideDock,
            .disableForceQuit,
            .disableProcessSwitching,
            .disableSessionTermination,
            .disableAppleMenu,
            .disableMenuBarTransparency
        ]

        // 3) Ensure correct frame and make it front
        if let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }

        // 4) Prepare fade-in: start with alpha = 0, then order front, then animate to 1
        window.alphaValue = 0.0
        window.level = .screenSaver
        window.orderFrontRegardless()

        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("Break in progress")

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        }, completionHandler: nil)

        // 5) Start overlay timer/UI
        overlayView?.startOverlay()
    }

    func hide() {
        guard let window = window else { return }

        // Animate fade-out over 0.3 seconds, then order out in completion
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0.0
        }) { [weak self] in
            guard let self = self else { return }

            window.orderOut(nil)
            NSApp.presentationOptions = [] // Restore normal app behavior
            ProcessInfo.processInfo.enableSuddenTermination()
            ProcessInfo.processInfo.enableAutomaticTermination("Break ended")

            // **BUG FIX: Attempt to restore focus to the previous application (corrected)**
            if let bundleID = self.previousAppBundleID,
               bundleID != Bundle.main.bundleIdentifier { // Don't try to re-activate self if it was frontmost
                let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                if let appToActivate = apps.first {
                    // Use .activateAllWindows or an empty set []
                    // .activateAllWindows is generally a good default to bring the app forward.
                    appToActivate.activate(options: [.activateAllWindows])
                }
            }
            self.previousAppBundleID = nil // Clear it after use

            self.overlayView = nil
        }
    }
}

// MARK: - BreakOverlayView
class BreakOverlayView: NSView {
    let timerManager: TimerManager
    var timer: Timer?
    var breakEnded = false
    var onClose: (() -> Void)?
    let backgroundView = NSView()
    let label = NSTextField(labelWithString: "Time for a Break!")
    let subLabel = NSTextField(labelWithString: "Look at something 20 feet away")
    let timerLabel = NSTextField(labelWithString: "")
    let endLabel = NSTextField(labelWithString: "Break Ended")
    let closeButton = NSButton(title: "   Close Break   ", target: nil, action: nil)

    init(frame: CGRect, timerManager: TimerManager) {
        self.timerManager = timerManager
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.95).cgColor
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        backgroundView.frame = bounds
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.95).cgColor
        addSubview(backgroundView)

        label.font = NSFont.systemFont(ofSize: 36, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        subLabel.font = NSFont.systemFont(ofSize: 24, weight: .regular)
        subLabel.textColor = .white
        subLabel.alignment = .center
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subLabel)

        timerLabel.font = NSFont.systemFont(ofSize: 32, weight: .medium)
        timerLabel.textColor = .white
        timerLabel.alignment = .center
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timerLabel)

        endLabel.font = NSFont.systemFont(ofSize: 36, weight: .bold)
        endLabel.textColor = .white
        endLabel.alignment = .center
        endLabel.translatesAutoresizingMaskIntoConstraints = false
        endLabel.isHidden = true
        addSubview(endLabel)

        closeButton.title = "Close Break"
        closeButton.font = NSFont.systemFont(ofSize: 24, weight: .medium)
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = true
        closeButton.isHidden = true
        closeButton.target = self
        closeButton.action = #selector(closeBreak)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 120),

            subLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 24),

            timerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            timerLabel.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 32),

            endLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            endLabel.topAnchor.constraint(equalTo: topAnchor, constant: 180),

            closeButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: endLabel.bottomAnchor, constant: 32),
        ])
    }

    func startOverlay() {
        breakEnded = false
        endLabel.isHidden = true
        closeButton.isHidden = true
        label.isHidden = false
        subLabel.isHidden = false
        timerLabel.isHidden = false
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.95).cgColor
        updateTimerLabel()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateTimerLabel()
        }
    }

    func updateTimerLabel() {
        if timerManager.timeRemaining > 0 && timerManager.isBreakTime {
            let seconds = timerManager.timeRemaining
            timerLabel.stringValue = "\(seconds) seconds remaining"
        } else if !breakEnded {
            // Transition to "break ended" UI
            breakEnded = true
            timer?.invalidate()
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                self.backgroundView.layer?.backgroundColor = NSColor(
                    calibratedRed: 0.58,
                    green: 0.30,
                    blue: 0.18,
                    alpha: 1.0
                ).cgColor
            }, completionHandler: {
                self.label.isHidden = true
                self.subLabel.isHidden = true
                self.timerLabel.isHidden = true
                self.endLabel.isHidden = false
                self.closeButton.isHidden = false
            })
        }
    }

    @objc func closeBreak() {
        timer?.invalidate()
        onClose?()
    }
}
