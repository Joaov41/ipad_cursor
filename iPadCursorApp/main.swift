import Cocoa

print("========== MAIN.SWIFT EXECUTING ==========")

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
