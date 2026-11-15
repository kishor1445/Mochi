import AppKit

// Earlier versions run with `swift run` saved under the name "Mochi"; the app now always uses its
// bundle identifier. Bring the old pet along the first time.
if UserDefaults.standard.object(forKey: "mind.firstMet") == nil, Bundle.main.bundleIdentifier != "Mochi",
   let old = UserDefaults.standard.persistentDomain(forName: "Mochi") {
    for (key, value) in old { UserDefaults.standard.set(value, forKey: key) }
}

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
    _ = NSApplication.shared
    Render.run(to: args[i + 1])
    Render.settings(to: args[i + 1].replacingOccurrences(of: ".png", with: "-settings.png"))
    exit(0)
}

if args.contains("--audio-test") {
    // Developer helper: prints what the audio watcher detects for ~12 seconds.
    let w = AudioWatcher.shared
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
