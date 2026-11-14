import AppKit

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
    _ = NSApplication.shared
    Render.run(to: args[i + 1])
    Render.settings(to: args[i + 1].replacingOccurrences(of: ".png", with: "-settings.png"))
    exit(0)
}

if args.contains("--audio-test") {
    // Developer helper: prints what the audio watcher detects for ~12 seconds.
    let w = AudioWatcher()
    w.start()
    var last: MediaActivity? = nil
    let t = Timer(timeInterval: 0.5, repeats: true) { _ in
        if w.current != last { last = w.current; print("media:", w.current) }
    }
    RunLoop.main.add(t, forMode: .common)
    RunLoop.main.run(until: Date().addingTimeInterval(12))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()
