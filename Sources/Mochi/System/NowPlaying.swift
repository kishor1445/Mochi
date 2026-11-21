import Foundation

/// What the system's Now Playing says is playing: the same source as the media controls in Control Center.
///
/// Every app that plays media properly reports here (Spotify, Music, YouTube or any site in a browser,
/// podcast apps, video players), together with whether it is actually playing. Apps that merely hold the
/// speakers open (dictation tools, chat apps, an idle browser tab) never do, so this is far more accurate
/// than watching which apps use the speakers.
///
/// Since macOS 15.4 the MediaRemote framework behind it only answers Apple's own programs, so a tiny
/// script runs in `osascript` (an Apple program) and reports changes, one JSON line each. It never sees
/// the audio, only the player's name, the title and whether it is playing. No permission is needed.
final class NowPlaying {
    static let shared = NowPlaying()

    struct State: Equatable {
        var playing: Bool
        var app: String?        // bundle identifier of the player ("com.spotify.client", "com.google.Chrome")
        var name: String?       // its name as the system shows it ("Spotify")
        var title: String?
        var video: Bool         // the player says it is showing a video
    }

    /// The latest report, or nil while it isn't known (not started, or the helper can't run on this Mac).
    private(set) var state: State?
    /// Called on the main thread whenever `state` changes.
    var onChange: (() -> Void)?

    private var process: Process?
    private var buffer = Data()
    private var wanted = false
    private var failures = 0

    /// How often the helper looks. Twice a second keeps it cheap (about 0.3% of one core) while a pause
    /// still reaches the pet within half a second.
    static let interval = 0.5

    func start() {
        wanted = true
        guard process == nil else { return }
        launch()
    }

    func stop() {
        wanted = false
        process?.terminate()
        process = nil
        if state != nil { state = nil; onChange?() }
    }

    private func launch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-l", "JavaScript", "-e", Self.script]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty else { h.readabilityHandler = nil; return }
            DispatchQueue.main.async { self?.received(data) }
        }
        p.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async { self?.ended(ended) }
        }
        do {
            try p.run()
            process = p
        } catch {
            process = nil
            ended(nil)
        }
    }

    /// The helper stopped. Unless Mochi asked it to, start it again, backing off if it keeps failing:
    /// meanwhile `state` is nil and the audio watcher falls back to watching the speakers.
    private func ended(_ p: Process?) {
        guard p == nil || p === process else { return }
        process = nil
        buffer.removeAll()
        if state != nil { state = nil; onChange?() }
        guard wanted else { return }
        failures += 1
        guard failures <= 5 else { return }                        // it can't run here: stay on the fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(failures * 3)) { [weak self] in
            guard let self, self.wanted, self.process == nil else { return }
            self.launch()
        }
    }

    private func received(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            // The framework isn't there or misbehaved: say "unknown" so the speakers are watched instead.
            let next: State? = obj["error"] == nil ? Self.state(from: obj) : nil
            if next != nil { failures = 0 }
            if next != state { state = next; onChange?() }
        }
    }

    /// One report from the helper.
    static func state(from obj: [String: Any]) -> State {
        func text(_ key: String) -> String? {
            guard let s = obj[key] as? String, !s.isEmpty else { return nil }
            return s
        }
        return State(playing: obj["playing"] as? Bool ?? false, app: text("app"), name: text("name"),
                     title: text("title"), video: (obj["type"] as? Int) == 2)
    }

    /// Runs inside osascript. Reads Now Playing every `interval` seconds, prints a line when anything
    /// changes, and quits as soon as Mochi does (its parent process changes).
    private static let script = """
    ObjC.import('Foundation');
    ObjC.bindFunction('getppid', ['int', []]);
    $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/').load;
    const R = $.NSClassFromString('MRNowPlayingRequest');
    const out = $.NSFileHandle.fileHandleWithStandardOutput;
    const parent = $.getppid();
    function str(v) { return (v === undefined || v === null || v.isNil()) ? null : ObjC.unwrap(v); }
    function read() {
      if (R.isNil()) return {error: 'unavailable'};
      const client = R.localNowPlayingPlayerPath.client;
      const item = R.localNowPlayingItem;
      const md = item.isNil() ? null : item.metadata;
      return {
        playing: !!R.localIsPlaying,
        app: client.isNil() ? null : str(client.bundleIdentifier),
        name: client.isNil() ? null : str(client.displayName),
        title: md === null || md.isNil() ? null : str(md.title),
        type: md === null || md.isNil() ? 0 : Number(md.mediaType)
      };
    }
    let last = '';
    while ($.getppid() === parent) {
      let line;
      try { line = JSON.stringify(read()); } catch (e) { line = JSON.stringify({error: String(e)}); }
      if (line !== last) {
        out.writeData($(line + '\\n').dataUsingEncoding($.NSUTF8StringEncoding));
        last = line;
      }
      $.NSThread.sleepForTimeInterval(\(interval));
    }
    """
}
