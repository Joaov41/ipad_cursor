# iPad Cursor

A guided tour of the iPad-style cursor engine. Each section calls out the relevant Swift helpers along with concrete snippets you can paste into a playground or test harness.

## Core Utilities

- `CGPoint.offsetBy(delta:)`, `clampedMagnitude(maxLength:)`, `mixed(with:weight:)`, the operator overloads, and `dot(_:)` — in `iPadCursorApp/Utilities/MathHelpers.swift` (`lines 5, 9, 16, 34, 51`) — form the vector math toolbox used across the engine.

```swift
let start = CGPoint(x: 30, y: 40)
let offset = start.offsetBy(delta: CGPoint(x: 5, y: -3))
let limited = offset.clampedMagnitude(maxLength: 6)
let blended = start.mixed(with: limited, weight: 0.5)
let heading = (blended - start).normalized * 10
let projection = blended.dot(CGPoint(x: 1, y: 0))
let easedStep = (heading / 2) + CGPoint(x: 1, y: 1)
```

- `CGGeometry.aggregateScreenBounds()`, `clamp(_:to:)`, and `currentCursorLocation()` — `Utilities/MathHelpers.swift` (`lines 56, 66, 74`) — normalize multi-display coordinates so every cursor warp stays onscreen.

```swift
let fullDesktop = CGGeometry.aggregateScreenBounds()
let rawWarp = CGPoint(x: fullDesktop.maxX + 50, y: fullDesktop.minY - 50)
let safeWarp = CGGeometry.clamp(rawWarp, to: fullDesktop)
let currentPointer = CGGeometry.currentCursorLocation()
```

- `PerformanceMonitor.recordFrame()` and `framesPerSecond` — `iPadCursorApp/Utilities/PerformanceMonitor.swift` (`lines 10, 20`) — provide a lightweight FPS sampler for render diagnostics.

```swift
let monitor = PerformanceMonitor()
monitor.recordFrame()
monitor.recordFrame()
// ... after a few frames ...
let fps = monitor.framesPerSecond
print("Cursor engine running at \(fps.rounded()) fps")
```

- `SettingsManager` accessors and `registerDefaults()` — `iPadCursorApp/Settings/SettingsManager.swift` (`lines 20, 25, 35, 40, 48`) — persist feature toggles like magnets, friction, hover effects, and pointer sensitivity.

```swift
let settings = SettingsManager.shared
settings.magneticSnappingEnabled = true
settings.pointerSensitivity = 0.42
let friction = settings.momentumFriction         // stored or default 0.985
settings.hoverEffectsEnabled = false             // persists immediately
```

## Animation & Rendering

- `HoverEffects.state(for:)` — `iPadCursorApp/Animation/HoverEffects.swift` (`line 15`) — maps an `AccessibilityElement` to a hover color/intensity/pulse tuple.

```swift
let hover = HoverEffects()
let buttonElement = AccessibilityElement(
    element: AXUIElementCreateSystemWide(),
    frame: CGRect(x: 100, y: 100, width: 80, height: 40),
    role: AXRole.button,
    subrole: nil,
    label: "Submit",
    enabled: true,
    supportsPress: true,
    inCollection: false
)
let hoverState = hover.state(for: buttonElement)
```

- `ShapeMorpher.setTarget(shape:duration:)`, `resolvedShape(at:)`, `interpolate`, and `easeOutSpring` — `Animation/ShapeMorpher.swift` (`lines 20, 28, 40, 44`) — spring between cursor silhouettes.

```swift
let morpher = ShapeMorpher()
morpher.setTarget(shape: .capsule, duration: 0.22)
let current = morpher.resolvedShape(at: CACurrentMediaTime() + 0.1)
morpher.setTarget(shape: .circle) // re-target with spring easing
```

- `CursorRenderer.show()`, `hide()`, and `update(position:momentumActive:hoverState:)` — `CursorEngine/CursorRenderer.swift` (`lines 16, 48, 54`) — manage the overlay window and momentum glow.

```swift
let renderer = CursorRenderer()
renderer.show()
renderer.update(
    position: CGPoint(x: 400, y: 300),
    momentumActive: true,
    hoverState: HoverState(color: .systemBlue, intensity: 0.35, pulse: true)
)
renderer.hide()
```

- `CursorView.layout()`, `update(isMomentumActive:hoverState:)`, `updateLayer()`, `draw(_:)`, `animateToCurrentState()`, and `updatePulseAnimation()` — `CursorRenderer.swift` (`lines 88, 95, 110, 116, 136, 151`) — maintain layer setup, redraws, and pulse/scale animations whenever cursor state shifts.

```swift
// Inside CursorView
override func layout() {
    super.layout()
    updateLayer()
}

func update(isMomentumActive: Bool, hoverState: HoverState?) {
    if self.isMomentumActive != isMomentumActive {
        animateToCurrentState()
    }
    self.hoverState = hoverState
    updatePulseAnimation()
}
```

- `CursorHighlightOverlay.show(over:)` and `hide()` — `App/CursorHighlightOverlay.swift` (`lines 33, 46`) — keep a translucent panel aligned to the magnetised element.

```swift
let overlay = CursorHighlightOverlay()
overlay.show(over: CGRect(x: 500, y: 500, width: 120, height: 60))
// ... later ...
overlay.hide()
```

- `HighlightView.setupLayer()`, `updatePath(in:)`, and `layout()` — `App/CursorHighlightOverlay.swift` (`lines 66, 79, 94`) — build the rounded highlight outline and update its path whenever the panel resizes.

```swift
let highlight = HighlightView(frame: CGRect(x: 0, y: 0, width: 140, height: 80))
highlight.layout()                               // ensures CAShapeLayer path matches bounds
highlight.updatePath(in: highlight.bounds)       // can be called after manual resize
```

## Input & Physics

- `CursorEventMonitor.ensureAccessibilityPermission()`, `start()`, and `stop()` — `CursorEngine/CursorEventMonitor.swift` (`lines 21, 31, 83`) — wrap the CGEvent tap lifecycle with permission prompts.

```swift
guard CursorEventMonitor.ensureAccessibilityPermission() else { return }
let monitor = CursorEventMonitor()
if monitor.start() {
    // later when tearing down
    monitor.stop()
}
```

- `CursorEventMonitor.handleEvent(type:event:)` — `CursorEngine/CursorEventMonitor.swift` (`line 96`) — intercepts low-level mouse traffic for pass-through, modification, or suppression.

```swift
monitor.mouseHandler = { event, type in
    if type == .mouseMoved {
        event.setDoubleValueField(.mouseEventDeltaX, value: 0) // zero X movement
        return .modified(event)
    }
    return .passThrough(event)
}
```

- `MomentumPhysics.registerUserInput(delta:timestamp:)`, `cancelMomentum()`, `momentumDelta(at:)`, and `applyFriction(to:)` — `CursorEngine/MomentumPhysics.swift` (`lines 20, 28, 34, 56`) — model post-input glide with tunable friction and stop thresholds.

```swift
let physics = MomentumPhysics()
physics.registerUserInput(delta: CGPoint(x: 6, y: -3), timestamp: CACurrentMediaTime())
if let glide = physics.momentumDelta(at: CACurrentMediaTime() + 0.06) {
    print("Carry momentum by \(glide)")
}
physics.cancelMomentum() // immediately stop any glide
```

- `MagneticEngine.updateTrackedElement(_:)`, `shouldDisengage(currentPosition:delta:)`, `disengage(cooldown:)`, and `adjustedPosition(target:)`, along with `MagneticTarget.center()`, `distance(to:)`, and `magneticForce(from:strength:maximumOffset:)` — `CursorEngine/MagneticEngine.swift` (`lines 21, 30, 42, 49, 86, 90, 96`) — keep the cursor gently attracted to focusable frames.

```swift
let buttonTarget = MagneticTarget(
    frame: CGRect(x: 300, y: 220, width: 120, height: 44),
    priority: 2,
    isEligible: true
)
let magnet = MagneticEngine()
magnet.updateTrackedElement(buttonTarget)
let proposed = CGPoint(x: 340, y: 240)
let nudged = magnet.adjustedPosition(target: proposed)
if magnet.shouldDisengage(currentPosition: nudged, delta: CGPoint(x: 12, y: -1)) {
    magnet.disengage()
}
```

- `ElementTracker.bestTarget(around:heading:completion:)`, `score(for:at:heading:last:)`, plus `CGRect.centerDistance(to:)` / `edgeDistance(to:)` — `iPadCursorApp/UIDetection/ElementTracker.swift` (`lines 21, 91, 129, 136`) — asynchronously pick the most relevant accessibility element given motion history.

```swift
let tracker = ElementTracker()
tracker.bestTarget(around: CGPoint(x: 500, y: 400), heading: CGPoint(x: 1, y: 0)) { tracked in
    if let pick = tracked {
        print("Magnetise \(pick.accessibilityElement.label ?? "unknown") at \(pick.magneticTarget.center())")
    }
}
// score() combines inside/edge distances and heading alignment internally
```

## Accessibility Scanning

- `AccessibilityScanner.element(at:)` — `UIDetection/AccessibilityScanner.swift` (`line 15`) — queries the Accessibility API for the element directly under a point.

```swift
let scanner = AccessibilityScanner()
if let element = scanner.element(at: NSEvent.mouseLocation) {
    print("Hit role:", element.role ?? "unknown")
}
```

- `AccessibilityScanner.elements(around:radius:)` — `UIDetection/AccessibilityScanner.swift` (`line 16`) — samples a grid around the cursor to gather nearby interactable nodes.

```swift
let neighbors = scanner.elements(around: CGPoint(x: 600, y: 420), radius: 72)
neighbors.forEach { print("Candidate:", $0.label ?? "<no label>") }
```

- `AccessibilityScanner.siblingsNear(_:minCount:maxDepth:)` and `isInMenuHierarchy(at:)` — `UIDetection/AccessibilityScanner.swift` (`lines 37, 54`) — climb the hierarchy to detect structured clusters or menu ancestry.

```swift
let siblingCluster = scanner.siblingsNear(CGPoint(x: 640, y: 380))
let inMenu = scanner.isInMenuHierarchy(at: CGPoint(x: 100, y: 20))
```

- `AccessibilityScanner.captureElement(at:)` and `makeElement(from:)` — `UIDetection/AccessibilityScanner.swift` (`lines 69, 76`) — lift raw `AXUIElement` handles into the curated `AccessibilityElement` model.

```swift
if let raw = scanner.captureElement(at: CGPoint(x: 500, y: 400)),
   let wrapped = scanner.makeElement(from: raw) {
    print("Usable frame:", wrapped.frame)
}
```

- `AccessibilityElement.isInteractive(...)`, `hash(into:)`, and equality overload — `UIDetection/AccessibilityScanner.swift` (`lines 125, 150, 154`) — classify interactable roles and allow set/dictionary semantics.

```swift
let clickable = AccessibilityElement.isInteractive(
    role: AXRole.button,
    subrole: nil,
    supportsPress: true,
    inCollection: false
)
var seen = Set<AccessibilityElement>()
if clickable, let element = scanner.element(at: CGPoint(x: 320, y: 320)) {
    seen.insert(element)   // relies on hash(into:) and ==
}
```

- The `AXUIElement` extension (`frame`, `attributeString`, `attributeBool`, `parent()`, `children()`, `actionNames()`, `supportsPress()`, `isWithinCollectionContainer()`, `promoteToInteractive(maxDepth:)`, `frameOrUnion()`) — `UIDetection/AccessibilityScanner.swift` (`lines 160, 175, 181, 190, 203, 229, 239, 243, 261, 290`) — supplies the raw accessibility plumbing the scanner depends on.

```swift
let systemWide = AXUIElementCreateSystemWide()
if let focused = systemWide.attributeString(for: kAXFocusedUIElementAttribute as CFString),
   let parent = systemWide.parent() {
    print("Focused:", focused, "Parent role:", parent.attributeString(for: AXAttribute.role) ?? "?")
}
if let promoted = systemWide.promoteToInteractive() {
    let area = promoted.frameOrUnion()
    let canPress = promoted.supportsPress()
    print("Interactive frame:", area ?? .zero, "pressable:", canPress)
}
```

## Engine Coordination

- `CursorEngine.start()` and `stop()` — `CursorEngine/CursorEngine.swift` (`lines 40, 72`) — bootstrap the event tap, timers, and overlays, then tear them down cleanly.

```swift
let engine = CursorEngine.shared
engine.start()
// later when quitting or suspending
engine.stop()
```

- `configureEventHandling()` and `teardownEventHandling()` — `CursorEngine/CursorEngine.swift` (`lines 87, 94`) — wire the CGEvent callback into `handleMouseEvent` and release it during shutdown.

```swift
// inside CursorEngine
private func configureEventHandling() {
    eventMonitor.mouseHandler = { [weak self] event, type in
        guard let self else { return .passThrough(event) }
        return self.handleMouseEvent(event, type: type)
    }
}
```

- `handleMouseEvent(_:type:)` — `CursorEngine/CursorEngine.swift` (`line 99`) — is the heart of live input: filtering menu interactions, scaling deltas, updating momentum, and applying magnets.

```swift
// excerpt within CursorEngine.handleMouseEvent
let delta = CGPoint(
    x: rawDelta.x * sensitivityMultiplier,
    y: rawDelta.y * sensitivityMultiplier
)
momentumPhysics.registerUserInput(delta: delta, timestamp: now)
if userIsMoving && magneticEngine.isEngaged {
    magneticEngine.disengage(cooldown: magnetQuietPeriod)
}
```

- `startDisplayTimer()`, `stopDisplayTimer()`, and `tick()` — `CursorEngine/CursorEngine.swift` (`lines 182, 192, 197`) — drive the 120 Hz loop that advances inertial motion and reapplies magnet adjustments when the user is hands-off.

```swift
// inside CursorEngine.start()
startDisplayTimer()

// tick() runs on updateQueue and uses momentum before warping:
private func tick() {
    guard let momentumDelta = momentumPhysics.momentumDelta(at: now) else { return }
    let desired = magneticEngine.adjustedPosition(target: cursorPosition.offsetBy(delta: momentumDelta))
    CGWarpMouseCursorPosition(desired)
}
```

- `applyMenuSuppression(now:extend:)` and `refreshMagneticTarget(at:)` — `CursorEngine/CursorEngine.swift` (`lines 238, 256`) — avoid fighting native menus and asynchronously retarget magnets once suppression lifts.

```swift
// inside handleMouseEvent
if axScanner.isInMenuHierarchy(at: cursorPosition) {
    applyMenuSuppression(now: now, extend: true)
    return .passThrough(event)
}

// elsewhere
refreshMagneticTarget(at: cursorPosition)
```

- `applySettings()`, `observeSettings()`, `updateHoverState()`, `notifyStateChange()`, and `cocoaCoordinates(for:)` — `CursorEngine/CursorEngine.swift` (`lines 273, 278, 288, 304, 312`) — sync user preferences, broadcast state, and convert AX frames into Cocoa space for the highlight overlay.

```swift
applySettings() // updates friction + magnet enablement
updateHoverState() // shows/hides highlightOverlay based on activeElement
let converted = cocoaCoordinates(for: frameFromAX)
NotificationCenter.default.post(name: .cursorEngineStateDidChange, object: nil)
```

## UI & App Lifecycle

- `MenuBarController.setup()`, `tearDown()`, `toggleCursorControl(_:)`, `showPreferences(_:)`, `showControlPanel(_:)`, `quitApplication(_:)`, `buildMenu()`, and `syncToggleState()` — `App/MenuBarController.swift` (`lines 25, 49, 58, 67, 71, 75, 79, 103`) — install the status item, wire menu actions, and keep the toggle label matched to engine state.

```swift
let menuController = MenuBarController()
menuController.setup()
// menu items call toggleCursorControl(_:) etc.
menuController.tearDown()
```

- `ControlWindowController.show()` plus `ControlViewController.loadView()`, `viewDidLoad()`, `layoutUI()`, `updateUI()`, and `toggleEngine()` — `App/ControlWindow.swift` (`lines 24, 60, 72, 88, 108, 114`) — present a floating window to toggle the cursor experience.

```swift
let controlWindow = ControlWindowController()
controlWindow.show()

@objc private func toggleEngine() {
    CursorEngine.shared.isRunning ? CursorEngine.shared.stop() : CursorEngine.shared.start()
}
```

- `PreferencesWindowController.show()` — `Settings/PreferencesWindow.swift` (`line 18`) — centers and raises the preferences window on demand.

```swift
let prefs = PreferencesWindowController()
prefs.show()
```

- `PreferencesViewController.loadView()`, `viewDidLoad()`, `layoutPreferences()`, `labeledRow(label:control:)`, `syncSettings()`, `toggleMagneticSnapping(_:)`, `toggleHoverEffects(_:)`, `frictionChanged(_:)`, and `sensitivityChanged(_:)` — `Settings/PreferencesWindow.swift` (`lines 42, 48, 64, 88, 96, 103, 108, 113, 118`) — wire sliders and toggles back into `SettingsManager`.

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    layoutPreferences()
    syncSettings()
}

@objc private func sensitivityChanged(_ sender: NSSlider) {
    SettingsManager.shared.pointerSensitivity = sender.doubleValue
    NotificationCenter.default.post(name: .settingsDidChange, object: nil)
}
```

- `AppDelegate.applicationDidFinishLaunching(_:)`, `setupMainMenu()`, and `applicationWillTerminate(_:)` — `App/AppDelegate.swift` (`lines 17, 42, 58`) — request accessibility access, create the control window and menu bar hook, and ensure teardown runs on exit.

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    setupMainMenu()
    let hasAccess = AXIsProcessTrusted()
    controlWindowController = ControlWindowController()
    controlWindowController?.show()
}

func applicationWillTerminate(_ notification: Notification) {
    menuBarController?.tearDown()
}
```

