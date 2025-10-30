import ApplicationServices
import Cocoa
import CoreGraphics

final class CursorEventMonitor {
    enum EventDisposition {
        case passThrough(CGEvent)
        case modified(CGEvent)
        case suppress
    }

    typealias MouseHandler = (CGEvent, CGEventType) -> EventDisposition

    var mouseHandler: MouseHandler?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private let tapQueue = DispatchQueue(label: "com.example.iPadCursor.eventTap")

    static func ensureAccessibilityPermission() -> Bool {
        let options: CFDictionary = [AXTrustedCheckOption.prompt as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            NSLog("⚠️ Accessibility permission not yet granted for iPad Cursor.")
            NSLog("   Enable it in System Settings → Privacy & Security → Accessibility.")
        }
        return trusted
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        // DON'T prompt for permission here - just try to create the event tap
        // If it fails, it means permission isn't granted yet
        guard CursorEventMonitor.ensureAccessibilityPermission() else {
            NSLog("❌ CursorEventMonitor: Accessibility permission required before enabling the cursor engine.")
            return false
        }

        let eventMask = CGEventMask(
            (1 << CGEventType.mouseMoved.rawValue)
                | (1 << CGEventType.leftMouseDragged.rawValue)
                | (1 << CGEventType.rightMouseDragged.rawValue)
                | (1 << CGEventType.otherMouseDragged.rawValue)
        )

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<CursorEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            NSLog("❌ CursorEventMonitor: Failed to create event tap - permission not granted yet")
            NSLog("💡 Go to System Settings → Privacy & Security → Accessibility")
            NSLog("💡 Toggle 'iPad Cursor' ON, then try enabling again")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        tapQueue.async { [weak self] in
            guard let self, let source = self.runLoopSource else { return }
            let runLoop = CFRunLoopGetCurrent()
            self.tapRunLoop = runLoop
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }

        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop = tapRunLoop {
            CFRunLoopStop(runLoop)
        }

        runLoopSource = nil
        tapRunLoop = nil
        eventTap = nil
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let handler = mouseHandler else {
            return Unmanaged.passUnretained(event)
        }

        switch handler(event, type) {
        case .passThrough(let original):
            return Unmanaged.passUnretained(original)
        case .modified(let modified):
            return Unmanaged.passRetained(modified)
        case .suppress:
            return nil
        }
    }
}
