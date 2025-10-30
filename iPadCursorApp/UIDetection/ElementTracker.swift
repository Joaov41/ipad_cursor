import CoreGraphics
import Foundation
import QuartzCore

/// Keeps track of the most relevant accessibility element near the cursor.
final class ElementTracker {
    var searchRadius: CGFloat = 96
    var cacheDuration: TimeInterval = 0.35
    private let retentionRadius: CGFloat = 110

    private let scanner: AccessibilityScanner
    private var cachedElements: [AccessibilityElement] = []
    private var lastUpdateTime: CFTimeInterval = 0
    private var lastTrackedElement: AccessibilityElement?
    private let queue = DispatchQueue(label: "com.example.iPadCursor.elementTracker", qos: .userInteractive)

    init(scanner: AccessibilityScanner = AccessibilityScanner()) {
        self.scanner = scanner
    }

    func bestTarget(around cursorPosition: CGPoint,
                    heading: CGPoint? = nil,
                    completion: @escaping (TrackedElement?) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let now = CACurrentMediaTime()
            if now - self.lastUpdateTime > self.cacheDuration {
                self.cachedElements = self.scanner.elements(around: cursorPosition, radius: self.searchRadius)
                self.lastUpdateTime = now
            }

            let cluster = self.scanner.siblingsNear(cursorPosition)
            var candidates = cluster.isEmpty
                ? (self.scanner.element(at: cursorPosition).map { [$0] } ?? []) + self.cachedElements
                : cluster

            var seen = Set<AccessibilityElement>()
            candidates = candidates.filter { seen.insert($0).inserted }

            let direction = (heading ?? .zero).normalized
            let last = self.lastTrackedElement
            let scored = candidates
                .filter { $0.enabled }
                .map { element -> (AccessibilityElement, CGFloat) in
                    (element, self.score(for: element, at: cursorPosition, heading: direction, last: last))
                }
                .sorted { $0.1 > $1.1 }
            let target = scored.first?.0

            let preferredTarget: AccessibilityElement?
            if
                let last = self.lastTrackedElement,
                let preserved = candidates.first(where: { $0 == last }),
                preserved.frame.centerDistance(to: cursorPosition) < retentionRadius
            {
                if let candidate = target {
                    let preservedDistance = preserved.frame.centerDistance(to: cursorPosition)
                    let candidateDistance = candidate.frame.centerDistance(to: cursorPosition)
                    if candidate.priority > preserved.priority
                        || candidateDistance + 4 < preservedDistance {
                        preferredTarget = candidate
                    } else {
                        preferredTarget = preserved
                    }
                } else {
                    preferredTarget = preserved
                }
            } else {
                preferredTarget = target
            }

            self.lastTrackedElement = preferredTarget

            let tracked = preferredTarget.map {
                TrackedElement(
                    accessibilityElement: $0,
                    magneticTarget: MagneticTarget(frame: $0.frame, priority: $0.priority, isEligible: true)
                )
            }

            DispatchQueue.main.async {
                completion(tracked)
            }
        }
    }

    private func score(for element: AccessibilityElement,
                       at cursor: CGPoint,
                       heading: CGPoint,
                       last: AccessibilityElement?) -> CGFloat {
        let rect = element.frame
        let inside: CGFloat = rect.contains(cursor) ? 1.0 : 0.0
        let centerDistance = rect.centerDistance(to: cursor) + 0.001
        let edgeDistance = rect.edgeDistance(to: cursor) + 0.001

        let toCandidate = CGPoint(x: rect.midX - cursor.x, y: rect.midY - cursor.y).normalized
        let directionScore = max(0, heading.dot(toCandidate))

        let weightInside: CGFloat = 2.2
        let weightEdgeInv: CGFloat = 1.6
        let weightCenterInv: CGFloat = 0.5
        let weightDirection: CGFloat = 0.7
        let weightPriority: CGFloat = 0.15
        let weightLast: CGFloat = 0.10

        let inverseEdge = 1.0 / edgeDistance
        let inverseCenter = 1.0 / centerDistance
        let lastBonus: CGFloat = (last != nil && element == last) ? 1.0 : 0.0

        return inside * weightInside
            + inverseEdge * weightEdgeInv
            + inverseCenter * weightCenterInv
            + directionScore * weightDirection
            + CGFloat(element.priority) * weightPriority
            + lastBonus * weightLast
    }
}

struct TrackedElement {
    let accessibilityElement: AccessibilityElement
    let magneticTarget: MagneticTarget
}

private extension CGRect {
    func centerDistance(to point: CGPoint) -> CGFloat {
        let centerPoint = CGPoint(x: midX, y: midY)
        let dx = centerPoint.x - point.x
        let dy = centerPoint.y - point.y
        return sqrt(dx * dx + dy * dy)
    }

    func edgeDistance(to point: CGPoint) -> CGFloat {
        let dx = max(minX - point.x, 0, point.x - maxX)
        let dy = max(minY - point.y, 0, point.y - maxY)
        return sqrt(dx * dx + dy * dy)
    }
}
