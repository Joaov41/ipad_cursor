import Cocoa
import QuartzCore

/// Represents the hover highlight state to be rendered by the cursor overlay.
struct HoverState {
    let color: NSColor
    let intensity: CGFloat
    let pulse: Bool
}

/// Calculates hover visual feedback parameters for the active accessibility element.
final class HoverEffects {
    private var currentState = HoverState(color: .clear, intensity: 0, pulse: false)

    func state(for element: AccessibilityElement?) -> HoverState {
        guard let element = element else {
            currentState = HoverState(color: .clear, intensity: 0, pulse: false)
            return currentState
        }

        let color: NSColor
        if element.role == AXRole.button {
            color = NSColor.systemBlue
        } else if element.role == AXRole.link {
            color = NSColor.systemPurple
        } else {
            color = NSColor.controlAccentColor
        }

        let intensity: CGFloat = element.enabled ? 0.35 : 0.12
        let pulse = element.enabled
        currentState = HoverState(color: color, intensity: intensity, pulse: pulse)
        return currentState
    }
}
