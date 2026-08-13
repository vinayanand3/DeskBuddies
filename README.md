# DeskBuddies for macOS

DeskBuddies is a small native macOS desktop-pet app. Choose a cat, dog, sloth, or panda that changes color and behavior according to the Mac's supported thermal state, while also reacting to clicks like a digital fidget toy.

## Download

[Download DeskBuddies for macOS](https://github.com/vinayanand3/DeskBuddies/releases/latest/download/DeskBuddies.dmg)

DeskBuddies supports both Apple Silicon and Intel Macs running macOS 13 or newer. Download the DMG, open it, and drag **DeskBuddies** into **Applications**.

The current community build is locally code-signed but not Apple-notarized. On first launch, macOS may ask you to Control-click DeskBuddies in Applications, choose **Open**, and confirm **Open**. The app does not require network, sensor, accessibility, or administrator permissions.

## Features

- Transparent, borderless desktop-pet window
- Four persistent pet profiles: Cat, Dog, Sloth, and Panda, each with dedicated expressions, walking, grooming, and thermal artwork
- Character-specific movement pacing, including a deliberately slower Sloth stride and animation cadence
- Draggable pet with remembered screen position
- Selectable Stay Put and Walk Around movement modes
- Natural alternating front and hind-leg contacts using dedicated eight-frame cycles for every pet, with automatic edge reversal and direction-aware artwork confined to one third of the active display
- Autonomous sit, paw-lick, face-wash and stand-up grooming breaks during walking
- Desktop-level mode and optional **Always on Top** mode
- Four visual thermal states: nominal, fair, serious and critical
- Click reactions: delighted, wink and annoyed expressions with jump, tilt, shake, heart and speech reactions
- Pointer-rub scratching with a relaxed expression and purring pulse
- Persistent 70% to 140% pet-size control in the menu and Settings, with a 70% first-run default
- Idle animation, blinking, hover feedback, species-aware synthesized offline sounds, purr, grumble, and trackpad feedback
- Menu-bar controls and a small settings window
- Manual thermal previews so every color and hot-state reaction can be tested
- Completely local operation with no network connection
- Low-overhead animation lifecycle that suspends walking when disabled, occluded, locked, asleep, critically hot, or reduced by accessibility settings

## Privacy and thermal monitoring

DeskBuddies is completely offline. It contains no analytics, advertising, accounts, update checker, remote assets, or network client.

Thermal monitoring uses only Apple's supported `ProcessInfo.processInfo.thermalState` API. DeskBuddies does not access the SMC, private sensors, precise temperature values, files, contacts, location, microphone, or camera.

## Build from source

Requirements:

- macOS 13 or newer
- Xcode 15 or newer
- No third-party dependencies

1. Open `DeskBuddies.xcodeproj` in Xcode 15 or newer.
2. Select the **DeskBuddies** scheme and **My Mac** as the destination.
3. Press **Run**.
4. Or run `./script/build_and_run.sh` from the project directory to build and launch the native `.app` bundle.
5. If the pet is behind other windows, use the pet icon in the menu bar and enable **Always on Top**.

The first build may take a moment while Xcode compiles the app. No external dependencies are downloaded.

Swift Package Manager is also supported:

```bash
swift test
swift run DeskBuddies
```

To produce the same universal DMG and ZIP used by GitHub Releases:

```bash
./script/package_release.sh 1.0.0
```

The artifacts are written to `dist/DeskBuddies.dmg`, `dist/DeskBuddies.zip`, and `dist/SHA256SUMS.txt`.

## Using the pet

- Choose Cat, Dog, Sloth, or Panda from **Pet Profile** in the menu bar or Settings.
- Click the pet repeatedly to cycle through reactions.
- Rub the pointer back and forth over the pet to scratch it.
- Drag anywhere on the transparent pet window to reposition it.
- Use **Movement > Stay Put** or **Movement > Walk Around** from the menu-bar cat icon. Walking stays inside the third of the display where the pet was placed, and dragging it into another third switches its walking area. Walking pauses during interactions and dragging. It runs normally when Cool, slows with yellow artwork when Warm, becomes very slow with orange artwork when Hot, and stops with the red static expression when Critical.
- In Walk Around mode, your DeskBuddy takes a short grooming break after 8 to 13 seconds, then at natural randomized intervals of 18 to 32 seconds.
- Use the menu-bar cat icon to resize or reset the pet, toggle sound or switch window level.
- Watch the speech bubble and body color for the current Mac thermal state.
- Open **Settings** and change **Thermal display** to preview Cool, Warm, Hot or Critical. Return it to **System** for live monitoring.

## Thermal behavior

- **Cool:** normal mint artwork and normal walking speed.
- **Warm:** yellow artwork and slower walking.
- **Hot:** orange artwork and very slow walking.
- **Critical:** red static expression with autonomous movement suspended.

## Thermal-state limitation

DeskBuddies deliberately uses `ProcessInfo.processInfo.thermalState`, Apple's supported API. It reports system conditions as `nominal`, `fair`, `serious` or `critical`; it does not provide an exact Celsius value. Exact Mac sensor readings require undocumented or privileged sensor access and are intentionally outside this project.

## Native app notes

- Minimum target: macOS 13.
- All four pets' expression, walking, grooming, and thermal sprites are bundled local raster assets.
- `DeskBuddies.xcodeproj` builds a native menu-bar `.app` bundle at `build/DerivedData/Build/Products/Debug/DeskBuddies.app`.
- `Package.swift` remains available for lightweight SwiftPM builds and keeps the original source layout intact.
- Release profiling on an M1 Pro keeps Stay Put near the sub-1% target and Walk Around near the 2% to 5% target. The four-profile build remains a small 14 MB app bundle, with a bounded sprite cache that prevents unbounded memory growth while switching pets.
- The bundle identifier remains `com.tempurr.desktoppet` so users upgrading from the original prototype retain their settings and saved position.

## Contributing

Issues and pull requests are welcome. Please preserve offline operation, Apple's supported thermal API, the transparent draggable window, interaction accessibility, and the low-overhead animation lifecycle. Run `swift test` and a Release Xcode build before submitting changes.

## License

DeskBuddies is available under the [MIT License](LICENSE).
