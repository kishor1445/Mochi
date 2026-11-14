import AppKit

/// A snack that drops from the top of the screen for the pet to run to and eat.
final class Treat {
    private let window: NSWindow
    private(set) var x: CGFloat
    private var y: CGFloat
    private var vy: CGFloat = 0
    private(set) var landed = false
    let born = Date()

    init(emoji: String, x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false

        let label = NSTextField(labelWithString: emoji)
        label.font = NSFont.systemFont(ofSize: 26)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 2, width: 36, height: 32)
        window.contentView = label
        window.setFrameOrigin(NSPoint(x: x - 18, y: y))
        window.orderFrontRegardless()
    }

    func update(_ dt: CGFloat, floorY: CGFloat) {
        if !landed {
            vy -= 1500 * dt
            y += vy * dt
            if y <= floorY { y = floorY; landed = true }
        }
        window.setFrameOrigin(NSPoint(x: x - 18, y: y))
    }

    func remove() { window.orderOut(nil) }
}
