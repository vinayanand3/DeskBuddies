import XCTest
@testable import DeskBuddies

final class DeskBuddiesTests: XCTestCase {
    func testFirstRunPetSizeDefaultsToSeventyPercent() {
        let defaults = isolatedDefaults()
        let settings = PetSettings(defaults: defaults)

        XCTAssertEqual(settings.catScale, 0.70)
    }

    func testFirstRunPetProfileDefaultsToCat() {
        let defaults = isolatedDefaults()
        XCTAssertEqual(PetSettings(defaults: defaults).petProfile, .cat)
    }

    func testEveryPetProfileRoutesCatAssetNamesToItsOwnFamily() {
        XCTAssertEqual(PetProfile.cat.assetName(from: "TempurrWalk3"), "TempurrWalk3")
        XCTAssertEqual(PetProfile.dog.assetName(from: "TempurrWalk3"), "TempurrDogWalk3")
        XCTAssertEqual(PetProfile.sloth.assetName(from: "TempurrCritical"), "TempurrSlothCritical")
        XCTAssertEqual(PetProfile.panda.assetName(from: "TempurrRelaxed"), "TempurrPandaRelaxed")
    }

    func testNewPetProfilesUseExpandedWalkCycles() {
        XCTAssertEqual(PetProfile.cat.walkFrameCount, 8)
        XCTAssertEqual(PetProfile.dog.walkFrameCount, 8)
        XCTAssertEqual(PetProfile.sloth.walkFrameCount, 8)
        XCTAssertEqual(PetProfile.panda.walkFrameCount, 8)
    }

    func testSlothUsesACharacterAppropriateWalkingPace() {
        XCTAssertEqual(PetProfile.sloth.walkingSpeed, 10)
        XCTAssertEqual(PetProfile.sloth.walkingSpriteFrameInterval, 5)
        XCTAssertEqual(PetProfile.cat.walkingSpeed, 30)
        XCTAssertEqual(PetProfile.dog.walkingSpriteFrameInterval, 2)
        XCTAssertEqual(PetProfile.panda.walkingSpeed, 22)
        XCTAssertEqual(PetProfile.panda.walkingSpriteFrameInterval, 3)
    }

    func testThermalMotionPolicySlowsBeforeStopping() {
        let cool = ThermalMotionPolicy.policy(for: .nominal)
        let warm = ThermalMotionPolicy.policy(for: .fair)
        let hot = ThermalMotionPolicy.policy(for: .serious)
        let critical = ThermalMotionPolicy.policy(for: .critical)

        XCTAssertTrue(cool.allowsWalking)
        XCTAssertTrue(warm.allowsWalking)
        XCTAssertTrue(hot.allowsWalking)
        XCTAssertFalse(critical.allowsWalking)
        XCTAssertGreaterThan(cool.speedMultiplier, warm.speedMultiplier)
        XCTAssertGreaterThan(warm.speedMultiplier, hot.speedMultiplier)
        XCTAssertEqual(critical.speedMultiplier, 0)
        XCTAssertEqual(warm.animationAssetSuffix, "Fair")
        XCTAssertEqual(hot.animationAssetSuffix, "Serious")
    }

    func testMotionAssetsIncludeThermalSuffixes() {
        let motion = PetMotionModel()
        motion.setActivity(.walking)
        motion.setFrame(3)
        XCTAssertEqual(motion.assetName(thermalSuffix: "Fair"), "TempurrWalkFair3")
        XCTAssertEqual(
            PetProfile.dog.assetName(from: motion.assetName(thermalSuffix: "Serious")),
            "TempurrDogWalkSerious3"
        )
    }

    func testSavedPetSizeIsPreserved() {
        let defaults = isolatedDefaults()
        defaults.set(1.15, forKey: "catScale")

        let settings = PetSettings(defaults: defaults)

        XCTAssertEqual(settings.catScale, 1.15)
    }

    func testEveryThermalPreviewSelectsItsPresentationAndSprite() {
        let monitor = ThermalMonitor()
        let expected: [(mode: Int, title: String, asset: String)] = [
            (1, "Cool & comfy", "TempurrNominal"),
            (2, "A little warm", "TempurrFair"),
            (3, "Getting hot!", "TempurrSerious"),
            (4, "Too hot!", "TempurrCritical")
        ]

        for item in expected {
            let presentation = monitor.presentation(previewMode: item.mode)
            XCTAssertEqual(presentation.title, item.title)
            XCTAssertEqual(presentation.assetName, item.asset)
        }
    }

    func testSystemModeTracksTheCurrentProcessInfoThermalState() {
        let monitor = ThermalMonitor()
        XCTAssertEqual(monitor.effectiveState(previewMode: 0), ProcessInfo.processInfo.thermalState)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "DeskBuddiesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
