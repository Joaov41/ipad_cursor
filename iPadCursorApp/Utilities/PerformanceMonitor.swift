import Foundation
import QuartzCore

/// Lightweight FPS monitor used for debugging and optimization passes.
final class PerformanceMonitor {
    private let capacity = 120
    private var timestamps: [CFTimeInterval] = []
    private let lock = NSLock()

    func recordFrame() {
        lock.lock()
        defer { lock.unlock() }

        timestamps.append(CACurrentMediaTime())
        if timestamps.count > capacity {
            timestamps.removeFirst(timestamps.count - capacity)
        }
    }

    var framesPerSecond: Double {
        lock.lock()
        defer { lock.unlock() }

        guard timestamps.count >= 2 else { return 0 }
        guard let first = timestamps.first, let last = timestamps.last, last > first else { return 0 }

        let elapsed = last - first
        return Double(timestamps.count - 1) / elapsed
    }
}
