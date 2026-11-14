import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pet: PetController!
    private var settingsWindow: SettingsWindowController!
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        pet = PetController()
        settingsWindow = SettingsWindowController(onSayHi: { [weak self] in self?.pet.greet() },
                                                  onBringBack: { [weak self] in self?.pet.bringBack() },
                                                  onTreat: { [weak self] in self?.pet.giveTreat() })
        pet.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = makeMenu()
        pet.setContextMenu(makeMenu())              // right-click on the pet

        PetSettings.shared.$species.receive(on: DispatchQueue.main).sink { [weak self] s in
            self?.statusItem.button?.title = s.emoji
            self?.statusItem.menu = self?.makeMenu()
            self?.pet.setContextMenu(self?.makeMenu() ?? NSMenu())
        }.store(in: &cancellables)

        if CommandLine.arguments.contains("--settings") { settingsWindow.show() }
    }

    private func makeMenu() -> NSMenu {
        let name = PetSettings.shared.species.name
        let menu = NSMenu()
        menu.addItem(item("Say hi", #selector(sayHi)))
        menu.addItem(item("Pet \(name)", #selector(petIt)))
        menu.addItem(item("Come here", #selector(comeHere)))
        menu.addItem(item("Give a treat \(PetSettings.shared.species.treatEmoji)", #selector(giveTreat)))
        menu.addItem(item("Do a trick", #selector(trick)))
        menu.addItem(item("Go to sleep", #selector(sleepNow)))
        menu.addItem(.separator())
        menu.addItem(item("Bring \(name) back to screen", #selector(bringBack), key: "b"))
        menu.addItem(item("Choose pet & settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit", #selector(quit), key: "q"))
        return menu
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
    @objc private func bringBack() { pet.bringBack() }
    @objc private func openSettings() { settingsWindow.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
