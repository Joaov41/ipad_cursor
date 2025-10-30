import Cocoa
import CoreGraphics

extension CGPoint {
    func offsetBy(delta: CGPoint) -> CGPoint {
        CGPoint(x: x + delta.x, y: y + delta.y)
    }

    func clampedMagnitude(maxLength: CGFloat) -> CGPoint {
        let length = magnitude
        guard length > maxLength else { return self }
        let normalized = self / length
        return normalized * maxLength
    }

    func mixed(with target: CGPoint, weight: CGFloat) -> CGPoint {
        let clampedWeight = max(0, min(1, weight))
        return CGPoint(
            x: x * (1 - clampedWeight) + target.x * clampedWeight,
            y: y * (1 - clampedWeight) + target.y * clampedWeight
        )
    }

    var magnitude: CGFloat {
        sqrt(x * x + y * y)
    }

    var normalized: CGPoint {
        let length = magnitude
        guard length > 0 else { return .zero }
        return self / length
    }

    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        guard rhs != 0 else { return lhs }
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    func dot(_ other: CGPoint) -> CGFloat {
        x * other.x + y * other.y
    }
}

enum CGGeometry {
    static func aggregateScreenBounds() -> CGRect {
        // Union of all displays in Quartz display space (origin at top-left).
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.reduce(CGRect.null) { $0.union(CGDisplayBounds($1)) }
    }

    static func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        guard !rect.isNull else { return point }
        return CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    static func currentCursorLocation() -> CGPoint {
        // Quartz display space matches CGWarpMouseCursorPosition expectations.
        CGEvent(source: nil)?.location ?? .zero
    }
}
