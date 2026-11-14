import AppKit

final class BubbleView: NSView {
    static let tailH: CGFloat = 8
    static let hPad: CGFloat = 12
    static let vPad: CGFloat = 8

    private static let paragraph: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        return p
    }()

    static var attributes: [NSAttributedString.Key: Any] {
        let base = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 13) } ?? base
        return [.font: font,
                .foregroundColor: NSColor(calibratedRed: 0.2, green: 0.17, blue: 0.2, alpha: 1),
                .paragraphStyle: paragraph]
    }

    static func textSize(_ text: String) -> NSSize {
        let r = (text as NSString).boundingRect(with: NSSize(width: 190, height: 400),
                                                options: [.usesLineFragmentOrigin], attributes: attributes)
        return NSSize(width: ceil(r.width), height: ceil(r.height))
    }

    static func windowSize(for text: String) -> NSSize {
        let t = textSize(text)
        return NSSize(width: max(54, t.width + hPad * 2 + 3), height: t.height + vPad * 2 + tailH + 3)
    }

    var text = "" { didSet { needsDisplay = true } }
    var tailOnTop = false { didSet { needsDisplay = true } }
    var tailX: CGFloat = 40 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let th = Self.tailH
        let body = NSRect(x: 1.5, y: tailOnTop ? 1.5 : th + 1.5,
                          width: bounds.width - 3, height: bounds.height - th - 3)
        let bubble = NSBezierPath(roundedRect: body, xRadius: 12, yRadius: 12)

        let tail = NSBezierPath()
        let baseY = tailOnTop ? body.maxY : body.minY
        let apexY = tailOnTop ? body.maxY + th - 1 : body.minY - th + 1
        tail.move(to: NSPoint(x: tailX - 6, y: baseY))
        tail.line(to: NSPoint(x: tailX, y: apexY))
        tail.line(to: NSPoint(x: tailX + 6, y: baseY))

        let fill = NSColor(calibratedWhite: 1, alpha: 0.97)
        let border = NSColor(calibratedRed: 0.36, green: 0.3, blue: 0.32, alpha: 1)

        fill.setFill()
        bubble.fill()
        let tailFill = tail.copy() as! NSBezierPath
        tailFill.close(); tailFill.fill()

        border.setStroke()
        bubble.lineWidth = 1.5; bubble.stroke()
        tail.lineWidth = 1.5; tail.lineJoinStyle = .round; tail.stroke()

        // hide the seam where the tail joins the bubble
        fill.setStroke()
        let seam = NSBezierPath()
        seam.move(to: NSPoint(x: tailX - 5, y: baseY))
        seam.line(to: NSPoint(x: tailX + 5, y: baseY))
        seam.lineWidth = 2.6; seam.stroke()

        let size = Self.textSize(text)
        let rect = NSRect(x: (bounds.width - size.width) / 2,
                          y: body.minY + (body.height - size.height) / 2,
                          width: size.width, height: size.height)
        (text as NSString).draw(in: rect, withAttributes: Self.attributes)
    }
}

/// A small floating window that follows the pet and shows what it says.
final class SpeechBubble {
    private let window: NSWindow
    private let view = BubbleView()
    private var hideAt = Date.distantPast
    private var size = NSSize(width: 80, height: 40)
    private(set) var visible = false

    init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 80, height: 40),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = view
    }

    func say(_ text: String, for seconds: TimeInterval = 3.6) {
        view.text = text
        size = BubbleView.windowSize(for: text)
        hideAt = Date().addingTimeInterval(seconds)
        visible = true
    }

    /// Place the bubble above the pet (or below when there's no room / on the ceiling).
    func update(centerX: CGFloat, aboveY: CGFloat, belowY: CGFloat, preferBelow: Bool, limit: NSRect) {
        guard visible else { return }
        if Date() > hideAt {
            visible = false
            window.orderOut(nil)
            return
        }
        var x = centerX - size.width / 2
        x = min(max(x, limit.minX + 4), limit.maxX - size.width - 4)

        let fitsAbove = aboveY + size.height <= limit.maxY
        let below = preferBelow || !fitsAbove
        let y = below ? belowY - size.height : aboveY

        view.tailOnTop = below
        view.tailX = min(max(centerX - x, 18), size.width - 18)
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        if !window.isVisible { window.orderFrontRegardless() }
    }
}
