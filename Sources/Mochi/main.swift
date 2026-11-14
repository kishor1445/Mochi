import AppKit

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
    _ = NSApplication.shared
    Render.run(to: args[i + 1])
    Render.settings(to: args[i + 1].replacingOccurrences(of: ".png", with: "-settings.png"))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
