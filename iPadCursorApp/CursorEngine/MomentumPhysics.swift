import CoreGraphics
import QuartzCore

/// Calculates inertial cursor movement after direct input stops.
final class MomentumPhysics {
    // Higher ⇒ longer glide. Tuned for ~120 Hz update loop.
    var frictionCoefficient: CGFloat = 0.985
    var velocityCap: CGFloat = 48.0
    var stopThreshold: CGFloat = 0.08
    let activationDelay: CFTimeInterval = 0.045

    private var velocity = CGPoint.zero
    private var lastInputTimestamp: CFTimeInterval = CACurrentMediaTime()
    private var momentumActive = false

    var isMomentumActive: Bool {
        momentumActive
    }

    func registerUserInput(delta: CGPoint, timestamp: CFTimeInterval) {
        lastInputTimestamp = timestamp
        momentumActive = false

        let clampedDelta = delta.clampedMagnitude(maxLength: velocityCap)
        velocity = velocity.mixed(with: clampedDelta, weight: 0.35)
    }

    func cancelMomentum() {
        velocity = .zero
        momentumActive = false
        lastInputTimestamp = CACurrentMediaTime()
    }

    func momentumDelta(at time: CFTimeInterval) -> CGPoint? {
        if !momentumActive {
            guard time - lastInputTimestamp >= activationDelay else {
                return nil
            }
            guard velocity.magnitude >= stopThreshold else {
                velocity = .zero
                return nil
            }
            momentumActive = true
        }

        velocity = applyFriction(to: velocity)
        guard velocity.magnitude >= stopThreshold else {
            velocity = .zero
            momentumActive = false
            return nil
        }

        return velocity
    }

    private func applyFriction(to velocity: CGPoint) -> CGPoint {
        CGPoint(
            x: velocity.x * frictionCoefficient,
            y: velocity.y * frictionCoefficient
        )
    }
}
