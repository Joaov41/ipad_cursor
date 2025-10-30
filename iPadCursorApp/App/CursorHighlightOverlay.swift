import Cocoa
import QuartzCore

/// Lightweight overlay that highlights the currently magnetised target.
final class CursorHighlightOverlay {
    fileprivate enum OverlayConstants {
        static let cornerRadius: CGFloat = 8
        static let outlineWidth: CGFloat = 2
        static let padding: CGFloat = 4
    }

    private let panel: NSPanel
    private let highlightView: HighlightView

    init() {
        highlightView = HighlightView(frame: .zero)

        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelKey.assistiveTechHighWindow.rawValue))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.contentView = highlightView
    }

    func show(over rect: CGRect) {
        let paddedRect = rect.insetBy(dx: -OverlayConstants.padding, dy: -OverlayConstants.padding)
        let frameRect = panel.frameRect(forContentRect: paddedRect)
        panel.setFrame(frameRect, display: true, animate: false)
        if let contentView = panel.contentView {
            highlightView.frame = contentView.bounds
            highlightView.updatePath(in: contentView.bounds)
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }
}

private final class HighlightView: NSView {
    private var shapeLayer: CAShapeLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayer() {
        let layer = CAShapeLayer()
        layer.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
        layer.strokeColor = NSColor.controlAccentColor.cgColor
        layer.lineWidth = CursorHighlightOverlay.OverlayConstants.outlineWidth
        layer.shadowColor = NSColor.controlAccentColor.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 12
        layer.shadowOffset = .zero
        self.layer?.addSublayer(layer)
        shapeLayer = layer
    }

    func updatePath(in bounds: CGRect) {
        guard let layer = shapeLayer else { return }
        let path = CGPath(
            roundedRect: bounds,
            cornerWidth: CursorHighlightOverlay.OverlayConstants.cornerRadius,
            cornerHeight: CursorHighlightOverlay.OverlayConstants.cornerRadius,
            transform: nil
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.path = path
        shapeLayer?.frame = bounds
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        updatePath(in: bounds)
    }
}
