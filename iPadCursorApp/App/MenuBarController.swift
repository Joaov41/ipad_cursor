import Cocoa

final class MenuBarController {
    private enum Constants {
        static let statusBarIconName = NSImage.Name("iPadCursorMenuIcon")
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let cursorEngine = CursorEngine.shared
    private let preferencesWindowController = PreferencesWindowController()
    private lazy var toggleMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: "Enable iPad Cursor", action: #selector(toggleCursorControl(_:)), keyEquivalent: "")
        item.target = self
        return item
    }()
    private lazy var controlPanelMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: "Control Panel…", action: #selector(showControlPanel(_:)), keyEquivalent: "")
        item.target = self
        return item
    }()
    private var stateObserver: NSObjectProtocol?

    weak var controlWindowController: ControlWindowController?

    func setup() {
        statusItem.isVisible = true
        guard let button = statusItem.button else {
            NSLog("MenuBarController: status item button unavailable; menu bar item not shown")
            return
        }
        if let image = NSImage(named: Constants.statusBarIconName) ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil) {
            button.image = image
            button.image?.isTemplate = true
        } else {
            button.title = "◎"
        }
        statusItem.menu = buildMenu()
        syncToggleState()
        stateObserver = NotificationCenter.default.addObserver(
            forName: .cursorEngineStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncToggleState()
        }
        NSLog("MenuBarController: status item installed")
    }

    func tearDown() {
        cursorEngine.stop()
        if let observer = stateObserver {
            NotificationCenter.default.removeObserver(observer)
            stateObserver = nil
        }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func toggleCursorControl(_ sender: Any?) {
        if cursorEngine.isRunning {
            cursorEngine.stop()
        } else {
            cursorEngine.start()
        }
        syncToggleState()
    }

    @objc private func showPreferences(_ sender: Any?) {
        preferencesWindowController.show()
    }

    @objc private func showControlPanel(_ sender: Any?) {
        controlWindowController?.show()
    }

    @objc private func quitApplication(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(controlPanelMenuItem)

        menu.addItem(NSMenuItem.separator())

        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit iPad Cursor", action: #selector(quitApplication(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func syncToggleState() {
        toggleMenuItem.state = cursorEngine.isRunning ? .on : .off
        toggleMenuItem.title = cursorEngine.isRunning ? "Disable iPad Cursor" : "Enable iPad Cursor"
    }
}
