import Cocoa

/// Lightweight control surface so the app can be toggled without exposing the status item.
final class ControlWindowController: NSWindowController {
    private let contentController = ControlViewController()

    init() {
        let window = NSWindow(contentViewController: contentController)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.title = "iPad Cursor Control"
        window.setContentSize(NSSize(width: 360, height: 200))
        window.backgroundColor = .windowBackgroundColor
        super.init(window: window)
        NSLog("ControlWindowController: initialized with window: \(window)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            NSLog("ControlWindow: ERROR - window is nil!")
            return
        }
        NSLog("ControlWindow: presenting control window")
        NSLog("ControlWindow: window isVisible before: \(window.isVisible)")
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        NSLog("ControlWindow: window isVisible after: \(window.isVisible)")
        NSLog("ControlWindow: window frame: \(window.frame)")
        NSLog("ControlWindow: window level: \(window.level.rawValue)")
    }
}

private final class ControlViewController: NSViewController {
    private let cursorEngine = CursorEngine.shared
    private var stateObserver: NSObjectProtocol?

    private lazy var statusLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15, weight: .medium)
        return label
    }()

    private lazy var toggleButton: NSButton = {
        let button = NSButton(title: "Enable iPad Cursor", target: self, action: #selector(toggleEngine))
        button.bezelStyle = .rounded
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }()

    private lazy var instructionsLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Use the button above to enable or disable the iPad-style cursor experience. On macOS Sequoia, add the status item later via System Settings → Control Center if you prefer a menu bar toggle.")
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 200))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        layoutUI()
        updateUI()
        stateObserver = NotificationCenter.default.addObserver(
            forName: .cursorEngineStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateUI()
        }
    }

    deinit {
        if let observer = stateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func layoutUI() {
        let buttonStack = NSStackView(views: [toggleButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY

        let stack = NSStackView(views: [statusLabel, buttonStack, instructionsLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20)
        ])
    }

    private func updateUI() {
        let running = cursorEngine.isRunning
        statusLabel.stringValue = running ? "iPad Cursor is currently enabled." : "iPad Cursor is disabled."
        toggleButton.title = running ? "Disable" : "Enable"
    }

    @objc private func toggleEngine() {
        if cursorEngine.isRunning {
            cursorEngine.stop()
        } else {
            cursorEngine.start()
        }
    }
}
