import Cocoa
import QuartzCore
import ApplicationServices

/// Central coordinator that ties event monitoring, physics, magnetic snapping, and rendering together.
final class CursorEngine {
    static let shared = CursorEngine()

    private let eventMonitor = CursorEventMonitor()
    private let momentumPhysics = MomentumPhysics()
    private let magneticEngine = MagneticEngine()
    private let axScanner = AccessibilityScanner()
    private lazy var elementTracker = ElementTracker(scanner: axScanner)
    private let settings = SettingsManager.shared
    private let performanceMonitor = PerformanceMonitor()
    private let updateQueue = DispatchQueue(label: "com.example.iPadCursor.engine")
    private let highlightOverlay = CursorHighlightOverlay()
    private let menuCooldown: CFTimeInterval = 0.25
    private var menuSuppressedUntil: CFTimeInterval = 0
    // Smoothness + safety guards for momentum warps
    private let maxWarpPerFrame: CGFloat = 20.0
    private let warpGateInterval: CFTimeInterval = 2.0 / 120.0
    private var lastWarpTimestamp: CFTimeInterval = 0
    private let minInputDelta: CGFloat = 0.2
    // Live-input controls for magnet disengagement
    private let liveMoveThreshold: CGFloat = 0.6
    private let magnetQuietPeriod: CFTimeInterval = 0.12
    private var lastInputHeading: CGPoint = .zero

    private var displayTimer: DispatchSourceTimer?
    private var cursorPosition: CGPoint = NSEvent.mouseLocation
    private var lastEventTimestamp: CFTimeInterval = CACurrentMediaTime()
    private var settingsObserver: NSObjectProtocol?
    private var activeElement: AccessibilityElement?

    private(set) var isRunning = false

    private init() {}

    func start() {
        guard !isRunning else { return }

        // Debug: Print bundle identifier
        let bundleID = Bundle.main.bundleIdentifier ?? "UNKNOWN"
        NSLog("🔍 App Bundle ID: \(bundleID)")
        NSLog("🔍 App Path: \(Bundle.main.bundlePath)")

        // Check Accessibility permissions (log only, don't show alert every time)
        let trusted = AXIsProcessTrusted()
        NSLog("CursorEngine: Accessibility permission status: \(trusted ? "✅ GRANTED" : "❌ DENIED")")

        cursorPosition = CGGeometry.currentCursorLocation()
        lastEventTimestamp = CACurrentMediaTime()
        lastWarpTimestamp = 0
        lastInputHeading = .zero
        configureEventHandling()
        applySettings()
        observeSettings()

        guard eventMonitor.start() else {
            NSLog("⚠️ CursorEngine: Permission not yet granted - check System Settings")
            teardownEventHandling()
            return
        }

        startDisplayTimer()
        // Keep system cursor visible; rely on gentle magnetic adjustments only.
        isRunning = true
        notifyStateChange()
    }

    func stop() {
        guard isRunning else { return }

        teardownEventHandling()
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsObserver = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.highlightOverlay.hide()
        }
        isRunning = false
        notifyStateChange()
    }

    private func configureEventHandling() {
        eventMonitor.mouseHandler = { [weak self] event, type in
            guard let self else { return .passThrough(event) }
            return self.handleMouseEvent(event, type: type)
        }
    }

    private func teardownEventHandling() {
        eventMonitor.stop()
        stopDisplayTimer()
    }

    private func handleMouseEvent(_ event: CGEvent, type: CGEventType) -> CursorEventMonitor.EventDisposition {
        let now = CACurrentMediaTime()

        switch type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel:
            return .passThrough(event)
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .mouseMoved:
            break
        default:
            return .passThrough(event)
        }

        if axScanner.isInMenuHierarchy(at: cursorPosition) {
            applyMenuSuppression(now: now, extend: true)
            return .passThrough(event)
        }

        if now < menuSuppressedUntil {
            applyMenuSuppression(now: now, extend: false)
            return .passThrough(event)
        }

        let rawDelta = CGPoint(
            x: event.getDoubleValueField(.mouseEventDeltaX),
            y: event.getDoubleValueField(.mouseEventDeltaY)
        )
        let rawMagnitude = rawDelta.magnitude
        let userIsMoving = rawMagnitude >= liveMoveThreshold

        // Ignore our own CGWarp moves for a couple frames—they arrive with ~0 delta
        if now - lastWarpTimestamp < warpGateInterval && rawMagnitude < minInputDelta {
            return .passThrough(event)
        }
        // Don't treat micro jitter as "fresh input"
        if rawMagnitude < minInputDelta {
            return .passThrough(event)
        }

        // Tune overall cursor speed and correct the inverted Y axis that CGEvent reports.
        let sensitivityMultiplier = CGFloat(settings.pointerSensitivity)
        let delta = CGPoint(
            x: rawDelta.x * sensitivityMultiplier,
            y: rawDelta.y * sensitivityMultiplier
        )

        // Update physics with the direct input
        if userIsMoving {
            lastEventTimestamp = now
            lastInputHeading = delta
        }
        momentumPhysics.registerUserInput(delta: delta, timestamp: now)

        // If the magnet is engaged and the user starts moving, drop immediately
        if userIsMoving && magneticEngine.isEngaged {
            magneticEngine.disengage(cooldown: magnetQuietPeriod)
        }

        let bounds = CGGeometry.aggregateScreenBounds()
        let proposedPosition = CGGeometry.clamp(
            cursorPosition.offsetBy(delta: delta),
            to: bounds
        )
        var target = cursorPosition.mixed(with: proposedPosition, weight: 0.7)

        // Only apply magnets when motion is quiet; keeps travel feeling light.
        if !userIsMoving && settings.magneticSnappingEnabled {
            let snapped = magneticEngine.adjustedPosition(target: target)
            if magneticEngine.isEngaged && magneticEngine.lastDistanceToTarget <= magneticEngine.settleRadius {
                target = snapped
            } else {
                target = target.mixed(with: snapped, weight: 0.30)
            }
        }
        cursorPosition = target

        refreshMagneticTarget(at: cursorPosition)

        CGWarpMouseCursorPosition(cursorPosition)
        performanceMonitor.recordFrame()

        return .passThrough(event)
    }

    private func startDisplayTimer() {
        let timer = DispatchSource.makeTimerSource(flags: [], queue: updateQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 120.0, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        displayTimer = timer
        timer.resume()
    }

    private func stopDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()

        if axScanner.isInMenuHierarchy(at: cursorPosition) {
            applyMenuSuppression(now: now, extend: true)
            return
        }

        if now < menuSuppressedUntil {
            applyMenuSuppression(now: now, extend: false)
            return
        }

        // Let the physics decide when momentum starts; it already has an activationDelay
        guard let momentumDelta = momentumPhysics.momentumDelta(at: now) else { return }

        let bounds = CGGeometry.aggregateScreenBounds()

        // Apply the momentum delta to our current logical position
        var desired = CGGeometry.clamp(cursorPosition.offsetBy(delta: momentumDelta), to: bounds)

        // Optional: also run the position through the magnet while gliding
        if settings.magneticSnappingEnabled {
            desired = CGGeometry.clamp(magneticEngine.adjustedPosition(target: desired), to: bounds)
        }

        // Smooth warp toward the desired point, capped per frame
        let current = CGGeometry.currentCursorLocation()
        let step = (desired - current).clampedMagnitude(maxLength: maxWarpPerFrame)
        guard step.magnitude > 0.05 else { return }

        let newPos = current.offsetBy(delta: step)
        cursorPosition = newPos
        lastInputHeading = step
        CGWarpMouseCursorPosition(newPos)
        lastWarpTimestamp = CACurrentMediaTime()

        refreshMagneticTarget(at: newPos)
        performanceMonitor.recordFrame()
    }

    private func applyMenuSuppression(now: CFTimeInterval, extend: Bool) {
        if extend {
            menuSuppressedUntil = now + menuCooldown
        }

        cursorPosition = CGGeometry.currentCursorLocation()
        momentumPhysics.cancelMomentum()
        if extend || magneticEngine.isEngaged || activeElement != nil {
            magneticEngine.updateTrackedElement(nil)
        }
        magneticEngine.disengage(cooldown: menuCooldown)

        if activeElement != nil {
            activeElement = nil
            updateHoverState()
        }
    }

    private func refreshMagneticTarget(at position: CGPoint) {
        elementTracker.bestTarget(around: position, heading: lastInputHeading) { [weak self] tracked in
            guard let self else { return }

            if CACurrentMediaTime() < self.menuSuppressedUntil {
                self.magneticEngine.updateTrackedElement(nil)
                self.activeElement = nil
                self.updateHoverState()
                return
            }

            magneticEngine.updateTrackedElement(tracked?.magneticTarget)
            activeElement = tracked?.accessibilityElement
            updateHoverState()
        }
    }

    private func applySettings() {
        momentumPhysics.frictionCoefficient = CGFloat(settings.momentumFriction)
        magneticEngine.isEnabled = settings.magneticSnappingEnabled
    }

    private func observeSettings() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }
    }

    private func updateHoverState() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.settings.hoverEffectsEnabled else {
                self.highlightOverlay.hide()
                return
            }
            if self.magneticEngine.isEngaged, let frame = self.activeElement?.frame {
                let converted = self.cocoaCoordinates(for: frame)
                self.highlightOverlay.show(over: converted)
            } else {
                self.highlightOverlay.hide()
            }
        }
    }

    private func notifyStateChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cursorEngineStateDidChange, object: nil)
        }
    }
}

private extension CursorEngine {
    func cocoaCoordinates(for axFrame: CGRect) -> CGRect {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(axFrame) }) ?? NSScreen.main else {
            return axFrame
        }

        let flippedOriginY = screen.frame.maxY - (axFrame.origin.y + axFrame.height)
        let candidate = CGRect(
            x: axFrame.origin.x,
            y: flippedOriginY,
            width: axFrame.width,
            height: axFrame.height
        )

        if screen.frame.contains(candidate) {
            return candidate
        }
        return axFrame
    }
}
