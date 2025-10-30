import Cocoa
import QuartzCore

/// Draws the custom cursor overlay and handles shape morphing requests.
final class CursorRenderer {
    private enum Constants {
        static let baseSize: CGFloat = 22
        static let momentumGlowSize: CGFloat = 28
        static let animationDuration: CFTimeInterval = 0.12
    }

    private var window: NSWindow?
    private var cursorView: CursorView?
    private var lastPosition: CGPoint = .zero

    func show() {
        guard window == nil else { return }

        let contentRect = CGRect(
            x: 0,
            y: 0,
            width: Constants.baseSize,
            height: Constants.baseSize
        )

        let overlayWindow = NSWindow(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        overlayWindow.backgroundColor = .clear
        overlayWindow.isOpaque = false
        overlayWindow.hasShadow = false
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.level = .statusBar
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = CursorView(frame: contentRect)
        overlayWindow.contentView = view
        overlayWindow.orderFrontRegardless()

        cursorView = view
        window = overlayWindow
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        cursorView = nil
    }

    func update(position: CGPoint, momentumActive: Bool, hoverState: HoverState?) {
        guard let window else { return }

        let diameter = momentumActive ? Constants.momentumGlowSize : Constants.baseSize
        let origin = CGPoint(
            x: position.x - diameter / 2.0,
            y: position.y - diameter / 2.0
        )

        let frame = CGRect(origin: origin, size: CGSize(width: diameter, height: diameter))
        if window.frame != frame {
            window.setFrame(frame, display: true, animate: false)
        }

        cursorView?.update(isMomentumActive: momentumActive, hoverState: hoverState)
        lastPosition = position
    }
}

private final class CursorView: NSView {
    private var isMomentumActive = false
    private var hoverState: HoverState?
    private var pulseAnimationKey = "hoverPulse"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateLayer()
    }

    override var isFlipped: Bool { true }

    func update(isMomentumActive: Bool, hoverState: HoverState?) {
        let stateChanged = self.hoverState?.color != hoverState?.color ||
            self.hoverState?.intensity != hoverState?.intensity ||
            self.hoverState?.pulse != hoverState?.pulse

        let momentumChanged = self.isMomentumActive != isMomentumActive

        self.isMomentumActive = isMomentumActive
        self.hoverState = hoverState

        if momentumChanged || stateChanged {
            animateToCurrentState()
        }
    }

    override func updateLayer() {
        guard let layer else { return }
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        layer.backgroundColor = NSColor.clear.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.clear(bounds)

        let baseColor = hoverState?.color ?? NSColor.controlAccentColor
        let alpha = hoverState?.intensity ?? (isMomentumActive ? 0.35 : 0.22)
        let fillColor = baseColor.withAlphaComponent(alpha)

        ctx.setFillColor(fillColor.cgColor)
        ctx.addEllipse(in: bounds.insetBy(dx: 1, dy: 1))
        ctx.fillPath()

        ctx.setStrokeColor(baseColor.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(2)
        ctx.addEllipse(in: bounds.insetBy(dx: 2, dy: 2))
        ctx.strokePath()
    }

    private func animateToCurrentState() {
        guard let layer else { return }

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.duration = 0.15
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fromValue = layer.presentation()?.value(forKeyPath: "transform.scale") ?? 1.0
        animation.toValue = isMomentumActive ? 1.12 : 1.0
        layer.add(animation, forKey: "scale")
        layer.setAffineTransform(CGAffineTransform(scaleX: isMomentumActive ? 1.12 : 1.0, y: isMomentumActive ? 1.12 : 1.0))

        needsDisplay = true
        updatePulseAnimation()
    }

    private func updatePulseAnimation() {
        guard let layer else { return }

        if hoverState?.pulse == true {
            if layer.animation(forKey: pulseAnimationKey) == nil {
                let pulse = CABasicAnimation(keyPath: "opacity")
                pulse.fromValue = 0.8
                pulse.toValue = 1.0
                pulse.duration = 0.6
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(pulse, forKey: pulseAnimationKey)
            }
        } else {
            layer.removeAnimation(forKey: pulseAnimationKey)
        }
    }
}
