import AppKit
import Combine
import SwiftUI

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

    /// Layout: a small status card, the things you do most, two submenus, then app controls.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let species = PetSettings.shared.species
        let name = species.name
        menu.removeAllItems()

        let header = NSMenuItem()
        let host = NSHostingView(rootView: MenuHeader(mind: .shared, species: species))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        header.view = host
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(item("Give a Treat", "gift", #selector(giveTreat)))
        menu.addItem(item("Play Ball", "soccerball", #selector(playBall)))
        menu.addItem(submenu("Interact", "hand.wave", [
            item("Say Hi", "bubble.left", #selector(sayHi)),
            item("Pet \(name)", "heart", #selector(petIt)),
            item("Come Here", "cursorarrow.rays", #selector(comeHere)),
            item("Do a Trick", "sparkles", #selector(trick)),
            item("Go to Sleep", "moon.zzz", #selector(sleepNow))
        ]))
        if let left = pet.focusMinutesLeft {
            menu.addItem(item("Stop Focus (\(left) min left)", "timer", #selector(stopFocus)))
        } else {
            menu.addItem(submenu("Focus Session", "timer", [15, 25, 50].map { minutes in
                let i = item("\(minutes) Minutes", nil, #selector(startFocus(_:)))
                i.tag = minutes
                return i
            }))
        }
        menu.addItem(.separator())
        menu.addItem(item("Bring \(name) Back", "arrow.uturn.backward", #selector(bringBack), key: "b"))
        menu.addItem(item("Settings…", "gearshape", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Mochi", nil, #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ symbol: String?, _ sel: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        if let symbol { i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return i
    }

    private func submenu(_ title: String, _ symbol: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        let sub = NSMenu()
        sub.autoenablesItems = false
        items.forEach(sub.addItem)
        parent.submenu = sub
        return parent
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
