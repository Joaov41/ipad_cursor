import CoreGraphics
import Foundation
import QuartzCore

/// Calculates cursor attraction toward focusable UI elements.
final class MagneticEngine {
    var isEnabled: Bool = true
    var activationRadius: CGFloat = 58
    var releaseRadius: CGFloat = 75
    var magneticStrength: CGFloat = 420
    var maximumOffset: CGFloat = 8
    var settleRadius: CGFloat = 6
    var escapeVelocity: CGFloat = 14
    var releaseCooldown: TimeInterval = 0.35

    private var trackedElement: MagneticTarget?
    private(set) var isEngaged = false
    private(set) var lastDistanceToTarget: CGFloat = .infinity
    private var disengagedUntil: CFTimeInterval = 0

    func updateTrackedElement(_ element: MagneticTarget?) {
        trackedElement = element
        if element == nil {
            isEngaged = false
            lastDistanceToTarget = .infinity
            disengagedUntil = 0
        }
    }

    func shouldDisengage(currentPosition: CGPoint, delta: CGPoint) -> Bool {
        guard isEngaged,
              let element = trackedElement,
              delta.magnitude >= escapeVelocity
        else { return false }

        let toTarget = element.center() - currentPosition
        return toTarget.dot(delta) < 0
    }

    /// Immediately drop engagement and pause re-engagement for `cooldown` seconds.
    /// If `cooldown` is nil, uses `releaseCooldown`.
    func disengage(cooldown: TimeInterval? = nil) {
        isEngaged = false
        lastDistanceToTarget = .infinity
        let cd = cooldown ?? releaseCooldown
        disengagedUntil = CACurrentMediaTime() + cd
    }

    func adjustedPosition(target: CGPoint) -> CGPoint {
        guard isEnabled else { return target }
        if CACurrentMediaTime() < disengagedUntil {
            return target
        }
        guard
            let element = trackedElement,
            element.isEligible,
            element.distance(to: target) <= (isEngaged ? releaseRadius : activationRadius)
        else {
            isEngaged = false
            lastDistanceToTarget = .infinity
            return target
        }

        isEngaged = true
        let distance = element.distance(to: target)
        lastDistanceToTarget = distance

        if distance <= settleRadius {
            return element.center()
        }

        let force = element.magneticForce(
            from: target,
            strength: magneticStrength,
            maximumOffset: maximumOffset
        )
        return target.offsetBy(delta: force)
    }
}

struct MagneticTarget {
    let frame: CGRect
    let priority: Int
    let isEligible: Bool

    func center() -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    func distance(to point: CGPoint) -> CGFloat {
        let dx = center().x - point.x
        let dy = center().y - point.y
        return sqrt(dx * dx + dy * dy)
    }

    func magneticForce(from point: CGPoint, strength: CGFloat, maximumOffset: CGFloat) -> CGPoint {
        let centerPoint = center()
        let dx = centerPoint.x - point.x
        let dy = centerPoint.y - point.y
        let distance = max(distance(to: point), 1)
        let magnitude = min(strength / (distance * distance), maximumOffset)
        let normalizedX = dx / distance
        let normalizedY = dy / distance
        return CGPoint(x: normalizedX * magnitude, y: normalizedY * magnitude)
    }
}
