import Cocoa
import ApplicationServices

// @main removed - using manual main.swift instead
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var mainWindow: NSWindow?
    private var controlWindowController: ControlWindowController?

    override init() {
        super.init()
        NSLog("=================================================================")
        NSLog("========== APP DELEGATE INIT - NEW BUILD RUNNING ================")
        NSLog("=================================================================")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("=================================================================")
        print("========== APPLICATION DID FINISH LAUNCHING ====================")
        print("=================================================================")

        NSApp.setActivationPolicy(.regular)
        setupMainMenu()

        // Request accessibility permission ONCE at startup
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSLog("🔐 Accessibility permission: \(hasPermission ? "✅ GRANTED" : "❌ NOT GRANTED YET")")

        // Create and show the control window
        controlWindowController = ControlWindowController()
        controlWindowController?.show()
        mainWindow = controlWindowController?.window

        print("========== CONTROL WINDOW SHOWN ============")

        menuBarController = MenuBarController()
        menuBarController?.controlWindowController = controlWindowController
        menuBarController?.setup()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(NSMenuItem(title: "About iPad Cursor", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit iPad Cursor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("AppDelegate: will terminate")
        menuBarController?.tearDown()
    }
}
