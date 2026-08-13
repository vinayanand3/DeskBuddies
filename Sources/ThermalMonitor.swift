import Foundation
import SwiftUI

struct ThermalMotionPolicy: Equatable {
    let allowsWalking: Bool
    let speedMultiplier: Double
    let frameIntervalMultiplier: Int
    let animationAssetSuffix: String

    static func policy(for state: ProcessInfo.ThermalState) -> ThermalMotionPolicy {
        switch state {
        case .nominal:
            return ThermalMotionPolicy(
                allowsWalking: true,
                speedMultiplier: 1,
                frameIntervalMultiplier: 1,
                animationAssetSuffix: ""
            )
        case .fair:
            return ThermalMotionPolicy(
                allowsWalking: true,
                speedMultiplier: 0.6,
                frameIntervalMultiplier: 2,
                animationAssetSuffix: "Fair"
            )
        case .serious:
            return ThermalMotionPolicy(
                allowsWalking: true,
                speedMultiplier: 0.28,
                frameIntervalMultiplier: 3,
                animationAssetSuffix: "Serious"
            )
        case .critical:
            return ThermalMotionPolicy(
                allowsWalking: false,
                speedMultiplier: 0,
                frameIntervalMultiplier: 1,
                animationAssetSuffix: ""
            )
        @unknown default:
            return ThermalMotionPolicy(
                allowsWalking: false,
                speedMultiplier: 0,
                frameIntervalMultiplier: 1,
                animationAssetSuffix: ""
            )
        }
    }
}

final class ThermalMonitor: ObservableObject {
    @Published private(set) var state: ProcessInfo.ThermalState

    private var observer: NSObjectProtocol?

    init() {
        state = ProcessInfo.processInfo.thermalState

        // Accessing thermalState before registering is required by Apple's API.
        _ = ProcessInfo.processInfo.thermalState
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.state = ProcessInfo.processInfo.thermalState
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func effectiveState(previewMode: Int) -> ProcessInfo.ThermalState {
        switch previewMode {
        case 1: return .nominal
        case 2: return .fair
        case 3: return .serious
        case 4: return .critical
        default: return state
        }
    }

    func presentation(previewMode: Int) -> ThermalPresentation {
        switch effectiveState(previewMode: previewMode) {
        case .nominal:
            return ThermalPresentation(
                color: Color(red: 0.22, green: 0.76, blue: 0.66),
                accent: Color(red: 0.10, green: 0.48, blue: 0.42),
                title: "Cool & comfy",
                detail: "Your Mac feels great!",
                symbol: "sparkles",
                assetName: "TempurrNominal"
            )
        case .fair:
            return ThermalPresentation(
                color: Color(red: 0.96, green: 0.73, blue: 0.20),
                accent: Color(red: 0.72, green: 0.42, blue: 0.06),
                title: "A little warm",
                detail: "I'm taking it easy.",
                symbol: "sun.min.fill",
                assetName: "TempurrFair"
            )
        case .serious:
            return ThermalPresentation(
                color: Color(red: 0.96, green: 0.40, blue: 0.14),
                accent: Color(red: 0.68, green: 0.17, blue: 0.04),
                title: "Getting hot!",
                detail: "Give your Mac some air.",
                symbol: "thermometer.high",
                assetName: "TempurrSerious"
            )
        case .critical:
            return ThermalPresentation(
                color: Color(red: 0.88, green: 0.12, blue: 0.20),
                accent: Color(red: 0.52, green: 0.02, blue: 0.08),
                title: "Too hot!",
                detail: "Pause heavy work and cool down.",
                symbol: "exclamationmark.triangle.fill",
                assetName: "TempurrCritical"
            )
        @unknown default:
            return ThermalPresentation(
                color: .gray,
                accent: .secondary,
                title: "Checking temperature",
                detail: "One moment…",
                symbol: "questionmark.circle",
                assetName: "TempurrNominal"
            )
        }
    }
}

struct ThermalPresentation {
    let color: Color
    let accent: Color
    let title: String
    let detail: String
    let symbol: String
    let assetName: String
}
