import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var pet: PetController!
    private var settingsWindow: SettingsWindowController!
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        pet = PetController()
        settingsWindow = SettingsWindowController(onSayHi: { [weak self] in self?.pet.greet() },
                                                  onBringBack: { [weak self] in self?.pet.bringBack() },
                                                  onTreat: { [weak self] in self?.pet.giveTreat() },
                                                  onPlay: { [weak self] in self?.pet.playBall() })
        pet.start()

        // Both menus are filled in just before they open, so the status lines are always current.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = makeMenu()
        pet.setContextMenu(makeMenu())              // right-click on the pet

        PetSettings.shared.$species.receive(on: DispatchQueue.main).sink { [weak self] s in
            self?.statusItem.button?.title = s.emoji
        }.store(in: &cancellables)

        if CommandLine.arguments.contains("--settings") { settingsWindow.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PetMind.shared.save()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let species = PetSettings.shared.species
        let name = species.name
        let mind = PetMind.shared
        func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

        menu.removeAllItems()
        menu.addItem(info("\(name) is \(mind.feeling.label.lowercased()) \(mind.feeling.emoji)"))
        menu.addItem(info("⚡️ \(pct(mind.energy))   \(species.treatEmoji) \(pct(mind.fullness))   💖 \(pct(mind.joy))"))
        menu.addItem(info("\(mind.bondTitle) · level \(mind.level) · day \(mind.daysTogether)"))
        menu.addItem(.separator())
        menu.addItem(item("Say hi", #selector(sayHi)))
        menu.addItem(item("Pet \(name)", #selector(petIt)))
        menu.addItem(item("Come here", #selector(comeHere)))
        menu.addItem(item("Give a treat \(species.treatEmoji)", #selector(giveTreat)))
        menu.addItem(item("Play ball \(species.toyEmoji)", #selector(playBall)))
        menu.addItem(item("Do a trick", #selector(trick)))
        menu.addItem(item("Go to sleep", #selector(sleepNow)))
        menu.addItem(.separator())
        if let left = pet.focusMinutesLeft {
            menu.addItem(item("Stop focus session (\(left) min left)", #selector(stopFocus)))
        } else {
            let focus = NSMenuItem(title: "Focus session", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            sub.autoenablesItems = false
            for minutes in [15, 25, 50] {
                let i = item("\(minutes) minutes", #selector(startFocus(_:)))
                i.tag = minutes
                sub.addItem(i)
            }
            focus.submenu = sub
            menu.addItem(focus)
        }
        menu.addItem(.separator())
        menu.addItem(item("Bring \(name) back to screen", #selector(bringBack), key: "b"))
        menu.addItem(item("Choose pet & settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit", #selector(quit), key: "q"))
    }

    private func info(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    private func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func sayHi() { pet.greet() }
    @objc private func petIt() { pet.petted() }
    @objc private func comeHere() { pet.comeHere() }
    @objc private func sleepNow() { pet.sleepNow() }
    @objc private func trick() { pet.trick() }
    @objc private func giveTreat() { pet.giveTreat() }
    @objc private func playBall() { pet.playBall() }
    @objc private func startFocus(_ sender: NSMenuItem) { pet.startFocus(minutes: sender.tag) }
    @objc private func stopFocus() { pet.stopFocus() }
    @objc private func bringBack() { pet.bringBack() }
    @objc private func openSettings() { settingsWindow.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
