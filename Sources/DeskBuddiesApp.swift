import SwiftUI
import AppKit
import Combine

@main
struct DeskBuddiesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.petSettings)
                .frame(width: 380, height: 480)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let petSettings = PetSettings()

    private var petController: DesktopPetController?
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private var stayPutItem: NSMenuItem?
    private var walkAroundItem: NSMenuItem?
    private var movementCancellable: AnyCancellable?
    private var profileItems: [PetProfile: NSMenuItem] = [:]
    private var profileCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        petController = DesktopPetController(settings: petSettings)
        petController?.showPet()
        installMenuBarItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        petController?.savePosition()
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "DeskBuddies")
        item.button?.toolTip = "DeskBuddies desktop pets"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show DeskBuddies", action: #selector(showPet), keyEquivalent: ""))

        let topItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop(_:)), keyEquivalent: "")
        topItem.state = petSettings.alwaysOnTop ? .on : .off
        menu.addItem(topItem)

        let soundItem = NSMenuItem(title: "Sound Effects", action: #selector(toggleSound(_:)), keyEquivalent: "")
        soundItem.state = petSettings.soundEnabled ? .on : .off
        menu.addItem(soundItem)

        let sizeItem = NSMenuItem()
        let sizeView = NSHostingView(rootView: MenuPetSizeView(settings: petSettings))
        sizeView.frame = NSRect(x: 0, y: 0, width: 230, height: 66)
        sizeItem.view = sizeView
        menu.addItem(sizeItem)

        let profileItem = NSMenuItem(title: "Pet Profile", action: nil, keyEquivalent: "")
        let profileMenu = NSMenu(title: "Pet Profile")
        for profile in PetProfile.allCases {
            let menuItem = NSMenuItem(
                title: profile.rawValue,
                action: #selector(selectPetProfile(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = profile.rawValue
            menuItem.image = NSImage(systemSymbolName: profile.symbol, accessibilityDescription: profile.rawValue)
            profileMenu.addItem(menuItem)
            profileItems[profile] = menuItem
        }
        profileItem.submenu = profileMenu
        menu.addItem(profileItem)

        let movementItem = NSMenuItem(title: "Movement", action: nil, keyEquivalent: "")
        let movementMenu = NSMenu(title: "Movement")
        let stayPutItem = NSMenuItem(title: "Stay Put", action: #selector(selectStayPut), keyEquivalent: "")
        let walkAroundItem = NSMenuItem(title: "Walk Around", action: #selector(selectWalkAround), keyEquivalent: "")
        stayPutItem.target = self
        walkAroundItem.target = self
        movementMenu.addItem(stayPutItem)
        movementMenu.addItem(walkAroundItem)
        movementItem.submenu = movementMenu
        menu.addItem(movementItem)
        self.stayPutItem = stayPutItem
        self.walkAroundItem = walkAroundItem
        updateMovementMenuStates()
        movementCancellable = petSettings.$movementMode
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMovementMenuStates() }
        profileCancellable = petSettings.$petProfile
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateProfileMenuStates() }
        updateProfileMenuStates()

        menu.addItem(NSMenuItem(title: "Give Your Pet a Scratch", action: #selector(scratchPet), keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DeskBuddies", action: #selector(quit), keyEquivalent: "q"))

        for menuItem in menu.items {
            menuItem.target = self
        }

        item.menu = menu
        statusItem = item
        updateProfileMenuStates()
    }

    @objc private func showPet() {
        petController?.showPet()
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        petSettings.alwaysOnTop.toggle()
        sender.state = petSettings.alwaysOnTop ? .on : .off
        petController?.applyWindowLevel()
    }

    @objc private func toggleSound(_ sender: NSMenuItem) {
        petSettings.soundEnabled.toggle()
        sender.state = petSettings.soundEnabled ? .on : .off
    }

    @objc private func resetPosition() {
        petController?.resetPosition()
    }

    @objc private func scratchPet() {
        petSettings.scratchRequestCount += 1
        petController?.showPet()
    }

    @objc private func selectStayPut() {
        petSettings.movementMode = 0
        updateMovementMenuStates()
    }

    @objc private func selectWalkAround() {
        petSettings.movementMode = 1
        petController?.showPet()
        updateMovementMenuStates()
    }

    @objc private func selectPetProfile(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let profile = PetProfile(rawValue: rawValue) else { return }
        petSettings.petProfile = profile
        petController?.showPet()
    }

    private func updateProfileMenuStates() {
        for (profile, item) in profileItems {
            item.state = petSettings.petProfile == profile ? .on : .off
        }
        statusItem?.button?.image = NSImage(
            systemSymbolName: petSettings.petProfile.symbol,
            accessibilityDescription: "DeskBuddies \(petSettings.petProfile.rawValue)"
        )
    }

    private func updateMovementMenuStates() {
        stayPutItem?.state = petSettings.movementMode == 0 ? .on : .off
        walkAroundItem?.state = petSettings.movementMode == 1 ? .on : .off
    }

    @objc private func openSettings() {
        if let settingsWindowController {
            settingsWindowController.showWindow(nil)
            settingsWindowController.window?.makeKeyAndOrderFront(nil)
        } else {
            let settingsView = SettingsView()
                .environmentObject(petSettings)
                .frame(width: 380, height: 480)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 480),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "DeskBuddies Settings"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: settingsView)
            window.center()
            settingsWindowController = NSWindowController(window: window)
            settingsWindowController?.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private struct MenuPetSizeView: View {
    @ObservedObject var settings: PetSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Pet Size", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int(settings.catScale * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(value: $settings.catScale, in: 0.7...1.4, step: 0.05)
                .controlSize(.small)
                .accessibilityLabel("Pet size")
                .accessibilityValue("\(Int(settings.catScale * 100)) percent")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 230, height: 66)
    }
}
