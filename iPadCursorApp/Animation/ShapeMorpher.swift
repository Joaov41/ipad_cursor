import CoreGraphics
import QuartzCore

struct CursorShape: Equatable {
    var size: CGSize
    var cornerRadius: CGFloat

    static let circle = CursorShape(size: CGSize(width: 22, height: 22), cornerRadius: 11)
    static let capsule = CursorShape(size: CGSize(width: 44, height: 28), cornerRadius: 14)
    static let roundedRect = CursorShape(size: CGSize(width: 48, height: 32), cornerRadius: 10)
}

/// Provides spring-based interpolation between cursor shapes.
final class ShapeMorpher {
    private var currentShape = CursorShape.circle
    private var targetShape = CursorShape.circle
    private var startTimestamp: CFTimeInterval = 0
    private var duration: CFTimeInterval = 0.18

    func setTarget(shape: CursorShape, duration: CFTimeInterval = 0.18) {
        guard targetShape != shape else { return }
        currentShape = resolvedShape(at: CACurrentMediaTime())
        targetShape = shape
        startTimestamp = CACurrentMediaTime()
        self.duration = duration
    }

    func resolvedShape(at currentTime: CFTimeInterval) -> CursorShape {
        guard duration > 0 else { return targetShape }
        let elapsed = min(max((currentTime - startTimestamp) / duration, 0), 1)
        let eased = easeOutSpring(elapsed)

        let width = interpolate(from: currentShape.size.width, to: targetShape.size.width, progress: eased)
        let height = interpolate(from: currentShape.size.height, to: targetShape.size.height, progress: eased)
        let radius = interpolate(from: currentShape.cornerRadius, to: targetShape.cornerRadius, progress: eased)

        return CursorShape(size: CGSize(width: width, height: height), cornerRadius: radius)
    }

    private func interpolate(from value: CGFloat, to target: CGFloat, progress: CGFloat) -> CGFloat {
        value + (target - value) * progress
    }

    private func easeOutSpring(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        let damping: CGFloat = 0.65
        let stiffness: CGFloat = 8.0
        return 1 - pow(damping, clamped * stiffness) * cos(clamped * .pi * 1.25)
    }
}
