import AppKit
import CoreAudio

/// What kind of sound is playing on the Mac right now.
enum MediaActivity: Equatable {
    case none
    case music      // Music, Spotify, ...
    case video      // QuickTime, VLC, IINA, ...
    case call       // Zoom, Teams, FaceTime, Discord, ...
    case other      // browsers and everything else
}

/// Notices which apps are playing audio, using Core Audio's process list.
/// This needs no permission and never hears the audio itself, it only sees that an app is outputting sound.
final class AudioWatcher {
    /// One watcher for the whole app, however many pets are on screen.
    static let shared = AudioWatcher()
    private var started = false
    private(set) var current: MediaActivity = .none
    private var candidate: MediaActivity = .none
    private var streak = 0
    private var timer: Timer?

    /// Real play/pause state for apps that keep their audio stream open while paused (Spotify, Music).
    /// They announce changes system-wide, which needs no permission.
    private var playing: [String: Bool] = [:]

    func start() {
        guard !started else { resume(); return }
        started = true
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
                           object: nil, queue: .main) { [weak self] n in self?.record("spotify", n) }
        for name in ["com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo"] {
            center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] n in
                self?.record("music", n)
            }
        }

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Stop polling while the Mac sleeps or the screen is locked.
    func pause() {
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        guard started, timer == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func record(_ app: String, _ note: Notification) {
        let state = (note.userInfo?["Player State"] as? String)?.lowercased()
        playing[app] = (state == "playing")
    }

    /// What was found at the last poll, for the Debug page: each app making sound and how it was read.
    private(set) var sources: [String] = []

    /// A sound has to last a few seconds before it counts, so notification dings don't,
    /// and has to be gone for a few seconds before the pet decides it stopped.
    private func poll() {
        let now = detect()
        if now == candidate { streak += 1 } else { candidate = now; streak = 1 }
        let needed = candidate == .none ? 4 : 3
        if candidate != current && streak >= needed { current = candidate }
    }

    private func detect() -> MediaActivity {
        var found = Set<MediaActivity>()
        var seen: [String] = []
        if #available(macOS 14.2, *) {
            for p in audioProcesses() where p.output {
                guard var kind = classify(p.bundleID) else {
                    if isPausable(p.bundleID) { seen.append("\(p.bundleID): open but not playing") }
                    continue
                }
                // A chat app only counts as a call while it is also using the microphone;
                // otherwise it is just an app that happens to be making (or holding) sound.
                if kind == .call, !p.input { kind = .other }
                found.insert(kind)
                seen.append("\(p.bundleID): \(Self.name(kind))")
            }
        } else if defaultOutputRunning() {
            found.insert(.other)
            seen.append("Something is using the speakers")
        }
        sources = seen
        if found.contains(.call) { return .call }
        if found.contains(.music) { return .music }
        if found.contains(.video) { return .video }
        if found.contains(.other) { return .other }
        return .none
    }

    static func name(_ kind: MediaActivity) -> String {
        switch kind {
        case .none: return "Nothing"
        case .music: return "Music"
        case .video: return "Video"
        case .call: return "Call"
        case .other: return "Other sound"
        }
    }

    private func isPausable(_ bundleID: String) -> Bool {
        let b = bundleID.lowercased()
        return b.contains("spotify") || b.contains("com.apple.music") || b.contains("com.apple.itunes")
    }

    // MARK: Classification

    private func classify(_ bundleID: String) -> MediaActivity? {
        let b = bundleID.lowercased()
        func has(_ keys: [String]) -> Bool { keys.contains { b.contains($0) } }

        // system sounds and helpers we should ignore
        if has(["com.apple.audio", "com.apple.coreaudio", "com.apple.systemsound", "com.apple.accessibility",
                "com.apple.siri", "com.apple.notificationcenter", "com.apple.speech", "com.apple.voiceover",
                "com.apple.controlcenter", "mochi"]) { return nil }

        // Spotify and Apple Music hold their audio stream open even when paused, so only count them
        // while they say they are actually playing. (Before the first play/pause/track change since
        // Mochi started, their state is unknown and they are ignored.)
        if has(["spotify"]) { return playing["spotify"] == true ? .music : nil }
        if has(["com.apple.music", "com.apple.itunes"]) { return playing["music"] == true ? .music : nil }

        if has(["us.zoom", "com.microsoft.teams", "com.apple.facetime", "slack", "skype", "webex", "discord",
                "com.apple.ichat", "whatsapp", "com.hnc"]) { return .call }
        if has(["tidal", "amazon.music", "garageband", "ableton", "deezer", "soundcloud", "pandora", "vox",
                "swinsian"]) { return .music }
        if has(["quicktime", "videolan", "iina", "com.apple.tv", "plex", "mpv", "netflix", "infuse", "disney"]) { return .video }
        return .other           // browsers and anything else that makes sound
    }

    // MARK: Core Audio

    struct AudioProcess {
        let bundleID: String
        let output: Bool        // sending sound to the speakers
        let input: Bool         // listening to the microphone
    }

    @available(macOS 14.2, *)
    private func audioProcesses() -> [AudioProcess] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }

        func flag(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Bool {
            var value: UInt32 = 0
            var vsize = UInt32(MemoryLayout<UInt32>.size)
            var vaddr = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                   mElement: kAudioObjectPropertyElementMain)
            return AudioObjectGetPropertyData(id, &vaddr, 0, nil, &vsize, &value) == noErr && value != 0
        }

        let me = ProcessInfo.processInfo.processIdentifier
        var result: [AudioProcess] = []
        for id in ids {
            let output = flag(id, kAudioProcessPropertyIsRunningOutput)
            let input = flag(id, kAudioProcessPropertyIsRunningInput)
            guard output || input else { continue }

            var pid: pid_t = 0
            var psize = UInt32(MemoryLayout<pid_t>.size)
            var paddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID,
                                                   mScope: kAudioObjectPropertyScopeGlobal,
                                                   mElement: kAudioObjectPropertyElementMain)
            if AudioObjectGetPropertyData(id, &paddr, 0, nil, &psize, &pid) == noErr, pid == me { continue }

            var name: Unmanaged<CFString>?
            var nsize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var naddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID,
                                                   mScope: kAudioObjectPropertyScopeGlobal,
                                                   mElement: kAudioObjectPropertyElementMain)
            var bundle = "unknown"
            if AudioObjectGetPropertyData(id, &naddr, 0, nil, &nsize, &name) == noErr, let s = name?.takeRetainedValue() {
                bundle = s as String
            }
            result.append(AudioProcess(bundleID: bundle, output: output, input: input))
        }
        return result
    }

    /// Fallback for older macOS: is anything using the default output device?
    private func defaultOutputRunning() -> Bool {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &device) == noErr else { return false }
        var running: UInt32 = 0
        var rsize = UInt32(MemoryLayout<UInt32>.size)
        var raddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                               mScope: kAudioObjectPropertyScopeGlobal,
                                               mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(device, &raddr, 0, nil, &rsize, &running) == noErr && running != 0
    }
}
