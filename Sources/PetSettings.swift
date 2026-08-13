import SwiftUI

enum PetProfile: String, CaseIterable, Identifiable {
    case cat = "Cat"
    case dog = "Dog"
    case sloth = "Sloth"
    case panda = "Panda"

    var id: String { rawValue }
    var assetPrefix: String { "Tempurr\(rawValue)" }

    func assetName(from catAssetName: String) -> String {
        guard self != .cat else { return catAssetName }
        return catAssetName.replacingOccurrences(of: "Tempurr", with: assetPrefix)
    }

    var symbol: String {
        switch self {
        case .cat: return "cat.fill"
        case .dog: return "dog.fill"
        case .sloth: return "leaf.fill"
        case .panda: return "pawprint.fill"
        }
    }

    var walkFrameCount: Int {
        8
    }

    var walkingSpeed: Double {
        switch self {
        case .cat: return 30
        case .dog: return 34
        case .sloth: return 10
        case .panda: return 22
        }
    }

    var walkingSpriteFrameInterval: Int {
        switch self {
        case .cat, .dog: return 2
        case .sloth: return 5
        case .panda: return 3
        }
    }
}

final class PetSettings: ObservableObject {
    private let defaults: UserDefaults

    private enum Keys {
        static let alwaysOnTop = "alwaysOnTop"
        static let soundEnabled = "soundEnabled"
        static let showBubble = "showBubble"
        static let thermalPreview = "thermalPreview"
        static let catScale = "catScale"
        static let movementMode = "movementMode"
        static let petProfile = "petProfile"
    }

    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }

    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    @Published var showBubble: Bool {
        didSet { defaults.set(showBubble, forKey: Keys.showBubble) }
    }

    /// 0 follows the real Mac; 1...4 preview the four supported thermal states.
    @Published var thermalPreview: Int {
        didSet { defaults.set(thermalPreview, forKey: Keys.thermalPreview) }
    }

    @Published var catScale: Double {
        didSet { defaults.set(catScale, forKey: Keys.catScale) }
    }

    @Published var scratchRequestCount = 0

    @Published var petProfile: PetProfile {
        didSet { defaults.set(petProfile.rawValue, forKey: Keys.petProfile) }
    }

    /// 0 stays where placed; 1 walks horizontally along the current desktop.
    @Published var movementMode: Int {
        didSet { defaults.set(movementMode, forKey: Keys.movementMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? false
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        showBubble = defaults.object(forKey: Keys.showBubble) as? Bool ?? true
        thermalPreview = defaults.integer(forKey: Keys.thermalPreview)
        catScale = defaults.object(forKey: Keys.catScale) as? Double ?? 0.7
        movementMode = defaults.integer(forKey: Keys.movementMode)
        petProfile = PetProfile(rawValue: defaults.string(forKey: Keys.petProfile) ?? "") ?? .cat
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: PetSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: settings.petProfile.symbol)
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DeskBuddies")
                        .font(.title2.bold())
                    Text("A playful thermal desktop pet")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle("Keep pet above other windows", isOn: $settings.alwaysOnTop)
            Toggle("Play interaction sounds", isOn: $settings.soundEnabled)
            Toggle("Show thermal speech bubble", isOn: $settings.showBubble)

            Picker("Pet profile", selection: $settings.petProfile) {
                ForEach(PetProfile.allCases) { profile in
                    Label(profile.rawValue, systemImage: profile.symbol).tag(profile)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Pet size")
                    Spacer()
                    Text("\(Int(settings.catScale * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.catScale, in: 0.7...1.4, step: 0.05) {
                    Text("Pet size")
                } minimumValueLabel: {
                    Image(systemName: "cat")
                } maximumValueLabel: {
                    Image(systemName: "cat.fill")
                }
            }

            Button {
                settings.scratchRequestCount += 1
            } label: {
                Label("Give your pet a scratch", systemImage: "hand.point.up.left.fill")
            }

            Picker("Movement", selection: $settings.movementMode) {
                Text("Stay Put").tag(0)
                Text("Walk Around").tag(1)
            }
            .pickerStyle(.segmented)

            Picker("Thermal display", selection: $settings.thermalPreview) {
                Text("System").tag(0)
                Text("Cool").tag(1)
                Text("Warm").tag(2)
                Text("Hot").tag(3)
                Text("Critical").tag(4)
            }
            .pickerStyle(.menu)

            Spacer()

            Text("Use System for live monitoring. The other choices let you preview each color. DeskBuddies does not read private sensors or report an exact temperature.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
    }
}
