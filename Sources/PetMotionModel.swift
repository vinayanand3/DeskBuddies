import Combine
import Foundation

enum PetAutonomousActivity {
    case idle
    case walking
    case grooming
}

final class PetMotionModel: ObservableObject {
    @Published private(set) var activity: PetAutonomousActivity = .idle
    @Published private(set) var frame = 0
    @Published private(set) var facingLeft = false
    @Published private(set) var animationsEnabled = false

    func setActivity(_ newValue: PetAutonomousActivity) {
        guard activity != newValue else { return }
        activity = newValue
    }

    func setFrame(_ newValue: Int) {
        guard frame != newValue else { return }
        frame = newValue
    }

    func advanceFrame(count: Int) {
        setFrame((frame + 1) % count)
    }

    func setFacingLeft(_ newValue: Bool) {
        guard facingLeft != newValue else { return }
        facingLeft = newValue
    }

    func setAnimationsEnabled(_ newValue: Bool) {
        guard animationsEnabled != newValue else { return }
        animationsEnabled = newValue
    }

    var assetName: String {
        assetName(thermalSuffix: "")
    }

    func assetName(thermalSuffix: String) -> String {
        switch activity {
        case .idle:
            return "TempurrNominal"
        case .walking:
            return "TempurrWalk\(thermalSuffix)\(frame)"
        case .grooming:
            return "TempurrGroom\(thermalSuffix)\(frame)"
        }
    }
}
