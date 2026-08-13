import AppKit
import SwiftUI
import CoreGraphics
import Combine

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class DesktopPetController: NSObject {
    private static let basePanelSize: CGFloat = 220
    private static let walkingUpdatesPerSecond = 14

    private enum PositionKeys {
        static let x = "petWindowX"
        static let y = "petWindowY"
    }

    private let settings: PetSettings
    private let panel: PetPanel
    private let thermalMonitor = ThermalMonitor()
    private let motionModel = PetMotionModel()
    private var cancellables = Set<AnyCancellable>()
    private var dragStartOrigin: NSPoint?
    private var dragStartMouseLocation: NSPoint?
    private var walkingTimer: DispatchSourceTimer?
    private var walkingTick = 0
    private var walkingDirection: CGFloat = 1
    private var walkingPositionX: CGFloat?
    private var walkingZoneIndex: Int?
    private var walkingPauseTicksRemaining = 0
    private var walkingTicksUntilGrooming = 0
    private var groomingSequenceIndex = 0
    private var groomingFrameTicksRemaining = 0
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var sessionIsActive = true
    private var screenIsAwake = true

    private let groomingSequence: [(frame: Int, ticks: Int)] = [
        (0, 6),
        (1, 6),
        (2, 8),
        (3, 8),
        (4, 8),
        (3, 8),
        (2, 8),
        (4, 8),
        (5, 6)
    ]

    init(settings: PetSettings) {
        self.settings = settings

        let side = Self.basePanelSize * settings.catScale
        let size = NSSize(width: side, height: side)
        panel = PetPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init()

        configurePanel()
        restorePosition()
        configureLifecycleObservers()
        observeSettings()
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // SwiftUI owns dragging so AppKit does not compete for the same pointer updates.
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow

        let rootView = PetRootView(
            thermalMonitor: thermalMonitor,
            settings: settings,
            motionModel: motionModel,
            onDragChanged: { [weak self] translation in
                self?.pauseWalking(for: 3)
                self?.movePetToMouseLocation(initialTranslation: translation)
            },
            onDragEnded: { [weak self] in
                self?.finishDragging()
            },
            onInteraction: { [weak self] in
                self?.pauseWalking(for: 2.5)
            }
        )
        panel.contentViewController = NSHostingController(rootView: rootView)
        applyWindowLevel()
    }

    private func movePetToMouseLocation(initialTranslation: CGSize) {
        let mouseLocation = NSEvent.mouseLocation

        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            dragStartMouseLocation = NSPoint(
                x: mouseLocation.x - initialTranslation.width,
                y: mouseLocation.y + initialTranslation.height
            )
        }

        guard let dragStartOrigin, let dragStartMouseLocation else { return }
        panel.setFrameOrigin(NSPoint(
            x: dragStartOrigin.x + mouseLocation.x - dragStartMouseLocation.x,
            y: dragStartOrigin.y + mouseLocation.y - dragStartMouseLocation.y
        ))
    }

    private func finishDragging() {
        dragStartOrigin = nil
        dragStartMouseLocation = nil

        if settings.movementMode == 1,
           let screen = screenContainingPet() ?? NSScreen.main {
            updateWalkingZone(in: screen)
            var origin = panel.frame.origin
            origin.x = clampedWalkingX(origin.x, in: screen.visibleFrame)
            panel.setFrameOrigin(origin)
        }

        walkingPositionX = panel.frame.origin.x
        savePosition()
    }

    private func configureLifecycleObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        lifecycleObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sessionIsActive = false
            self?.reconcileAnimationActivity()
        })

        lifecycleObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sessionIsActive = true
            self?.reconcileAnimationActivity()
        })

        lifecycleObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.screenIsAwake = false
            self?.reconcileAnimationActivity()
        })

        lifecycleObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.screenIsAwake = true
            self?.reconcileAnimationActivity()
        })

        lifecycleObservers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reconcileAnimationActivity()
        })

        lifecycleObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.reconcileAnimationActivity()
        })

        lifecycleObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didHideNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.reconcileAnimationActivity()
        })

        lifecycleObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didUnhideNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.reconcileAnimationActivity()
        })
    }

    private func reconcileAnimationActivity() {
        let isVisible = panel.isVisible && panel.occlusionState.contains(.visible)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let animationsEnabled = sessionIsActive && screenIsAwake && isVisible && !reduceMotion
        motionModel.setAnimationsEnabled(animationsEnabled)

        let thermalState = thermalMonitor.effectiveState(previewMode: settings.thermalPreview)
        let thermalPolicy = ThermalMotionPolicy.policy(for: thermalState)
        let shouldWalk = animationsEnabled
            && settings.movementMode == 1
            && thermalPolicy.allowsWalking

        if shouldWalk {
            startWalkingTimerIfNeeded()
        } else {
            stopWalkingTimer()
            motionModel.setActivity(.idle)
        }
    }

    private func observeSettings() {
        settings.$alwaysOnTop
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyWindowLevel() }
            .store(in: &cancellables)

        settings.$catScale
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] scale in self?.resizePet(to: scale) }
            .store(in: &cancellables)

        settings.$movementMode
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in self?.movementModeChanged(mode) }
            .store(in: &cancellables)

        settings.$thermalPreview
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reconcileAnimationActivity() }
            .store(in: &cancellables)

        settings.$petProfile
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.motionModel.setFrame(0) }
            .store(in: &cancellables)

        thermalMonitor.$state
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reconcileAnimationActivity() }
            .store(in: &cancellables)

    }

    private func startWalkingTimerIfNeeded() {
        guard walkingTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now(),
            repeating: 1.0 / Double(Self.walkingUpdatesPerSecond),
            leeway: .milliseconds(8)
        )
        timer.setEventHandler { [weak self] in
            self?.advanceWalking()
        }
        walkingTimer = timer
        timer.resume()
    }

    private func stopWalkingTimer() {
        walkingTimer?.setEventHandler {}
        walkingTimer?.cancel()
        walkingTimer = nil
    }

    private func movementModeChanged(_ mode: Int) {
        walkingPauseTicksRemaining = 0
        walkingTick = 0
        motionModel.setFrame(0)
        walkingPositionX = panel.frame.origin.x
        walkingZoneIndex = nil
        scheduleNextGrooming(initial: true)

        guard mode == 1 else {
            stopWalkingTimer()
            motionModel.setActivity(.idle)
            savePosition()
            return
        }

        placePetOnDesktopFloor()
        reconcileAnimationActivity()
    }

    private func placePetOnDesktopFloor() {
        guard let screen = screenContainingPet() ?? NSScreen.main else { return }
        updateWalkingZone(in: screen)
        var origin = panel.frame.origin
        origin.x = clampedWalkingX(origin.x, in: screen.visibleFrame)
        origin.y = screen.visibleFrame.minY + 8
        panel.setFrameOrigin(origin)
        walkingPositionX = panel.frame.origin.x
        savePosition()
    }

    private func advanceWalking() {
        if walkingPauseTicksRemaining > 0 {
            walkingPauseTicksRemaining -= 1
            motionModel.setActivity(.idle)
            return
        }

        guard settings.movementMode == 1,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let screen = screenContainingPet() ?? NSScreen.main else {
            motionModel.setActivity(.idle)
            return
        }

        let thermalState = thermalMonitor.effectiveState(previewMode: settings.thermalPreview)
        let thermalPolicy = ThermalMotionPolicy.policy(for: thermalState)
        guard thermalPolicy.allowsWalking else {
            motionModel.setActivity(.idle)
            return
        }

        if motionModel.activity == .grooming {
            advanceGrooming()
            return
        }

        if walkingTicksUntilGrooming <= 0 {
            startGrooming()
            return
        }

        motionModel.setActivity(.walking)
        walkingTicksUntilGrooming -= 1
        walkingTick += 1
        let frameInterval = settings.petProfile.walkingSpriteFrameInterval
            * thermalPolicy.frameIntervalMultiplier
        if walkingTick.isMultiple(of: frameInterval) {
            motionModel.advanceFrame(count: settings.petProfile.walkFrameCount)
        }

        if walkingZoneIndex == nil {
            updateWalkingZone(in: screen)
        }

        let bounds = walkingHorizontalBounds(in: screen.visibleFrame)
        let minimumX = bounds.minimum
        let maximumX = bounds.maximum
        let pointsPerTick = settings.petProfile.walkingSpeed
            * thermalPolicy.speedMultiplier
            * settings.catScale
            / Double(Self.walkingUpdatesPerSecond)
        let currentX = min(max(walkingPositionX ?? panel.frame.origin.x, minimumX), maximumX)
        var nextX = currentX + walkingDirection * pointsPerTick

        if nextX >= maximumX {
            nextX = maximumX
            walkingDirection = -1
            motionModel.setFacingLeft(true)
            motionModel.setFrame(0)
        } else if nextX <= minimumX {
            nextX = minimumX
            walkingDirection = 1
            motionModel.setFacingLeft(false)
            motionModel.setFrame(0)
        }

        walkingPositionX = nextX
        panel.setFrameOrigin(NSPoint(x: nextX, y: panel.frame.origin.y))
        if walkingTick.isMultiple(of: Self.walkingUpdatesPerSecond * 2) {
            savePosition()
        }
    }

    private func screenContainingPet() -> NSScreen? {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? panel.screen
    }

    private func updateWalkingZone(in screen: NSScreen) {
        let visible = screen.visibleFrame
        guard visible.width > 0 else {
            walkingZoneIndex = 0
            return
        }

        let centerX = min(max(panel.frame.midX, visible.minX), visible.maxX - 0.001)
        let relativeX = (centerX - visible.minX) / visible.width
        walkingZoneIndex = min(2, max(0, Int(relativeX * 3)))
    }

    private func walkingHorizontalBounds(in visible: NSRect) -> (minimum: CGFloat, maximum: CGFloat) {
        let zone = CGFloat(walkingZoneIndex ?? 0)
        let zoneWidth = visible.width / 3
        let zoneMinimumX = visible.minX + zone * zoneWidth
        let zoneMaximumX = zoneMinimumX + zoneWidth
        let minimumX = zoneMinimumX + 8
        let maximumX = max(minimumX, zoneMaximumX - panel.frame.width - 8)
        return (minimumX, maximumX)
    }

    private func clampedWalkingX(_ x: CGFloat, in visible: NSRect) -> CGFloat {
        let bounds = walkingHorizontalBounds(in: visible)
        return min(max(x, bounds.minimum), bounds.maximum)
    }

    func pauseWalking(for duration: TimeInterval) {
        let requestedTicks = Int(ceil(duration * Double(Self.walkingUpdatesPerSecond)))
        walkingPauseTicksRemaining = max(walkingPauseTicksRemaining, requestedTicks)
        motionModel.setActivity(.idle)
        groomingSequenceIndex = 0
        groomingFrameTicksRemaining = 0
        scheduleNextGrooming(initial: false)
    }

    private func startGrooming() {
        groomingSequenceIndex = 0
        let first = groomingSequence[0]
        groomingFrameTicksRemaining = first.ticks
        motionModel.setActivity(.grooming)
        motionModel.setFrame(first.frame)
    }

    private func advanceGrooming() {
        groomingFrameTicksRemaining -= 1
        guard groomingFrameTicksRemaining <= 0 else { return }

        groomingSequenceIndex += 1
        guard groomingSequenceIndex < groomingSequence.count else {
            motionModel.setActivity(.walking)
            motionModel.setFrame(0)
            scheduleNextGrooming(initial: false)
            return
        }

        let next = groomingSequence[groomingSequenceIndex]
        motionModel.setFrame(next.frame)
        groomingFrameTicksRemaining = next.ticks
    }

    #if DEBUG
    func previewGroomingForTesting() {
        let thermalPolicy = ThermalMotionPolicy.policy(
            for: thermalMonitor.effectiveState(previewMode: settings.thermalPreview)
        )
        guard settings.movementMode == 1,
              thermalPolicy.allowsWalking,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        walkingPauseTicksRemaining = 0
        startGrooming()
    }
    #endif

    private func scheduleNextGrooming(initial: Bool) {
        let overrideSeconds = ProcessInfo.processInfo.environment["TEMPURR_GROOMING_DELAY_SECONDS"]
            .flatMap(Int.init)
        let seconds = overrideSeconds
            ?? (initial ? Int.random(in: 8...13) : Int.random(in: 18...32))
        walkingTicksUntilGrooming = seconds * Self.walkingUpdatesPerSecond
    }

    private func resizePet(to scale: Double) {
        let oldFrame = panel.frame
        let newSide = Self.basePanelSize * scale
        let center = NSPoint(x: oldFrame.midX, y: oldFrame.midY)
        var newFrame = NSRect(
            x: center.x - newSide / 2,
            y: center.y - newSide / 2,
            width: newSide,
            height: newSide
        )

        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            newFrame.origin.x = min(max(newFrame.origin.x, visible.minX), visible.maxX - newSide)
            newFrame.origin.y = min(max(newFrame.origin.y, visible.minY), visible.maxY - newSide)

            if settings.movementMode == 1 {
                newFrame.origin.x = clampedWalkingX(newFrame.origin.x, in: visible)
            }
        }

        panel.setFrame(newFrame, display: true, animate: false)
        walkingPositionX = panel.frame.origin.x
        savePosition()
    }

    func applyWindowLevel() {
        if settings.alwaysOnTop {
            panel.level = .floating
        } else {
            let desktopLevel = CGWindowLevelForKey(.desktopWindow)
            panel.level = NSWindow.Level(rawValue: Int(desktopLevel) + 1)
        }
    }

    func showPet() {
        panel.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            self?.reconcileAnimationActivity()
        }
    }

    func savePosition() {
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: PositionKeys.x)
        UserDefaults.standard.set(origin.y, forKey: PositionKeys.y)
    }

    func resetPosition() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - 30,
            y: visible.minY + 30
        )
        panel.setFrameOrigin(origin)
        if settings.movementMode == 1 {
            updateWalkingZone(in: screen)
        }
        walkingPositionX = panel.frame.origin.x
        savePosition()
    }

    deinit {
        stopWalkingTimer()
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        lifecycleObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }

    private func restorePosition() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PositionKeys.x) != nil,
           defaults.object(forKey: PositionKeys.y) != nil {
            let origin = NSPoint(
                x: defaults.double(forKey: PositionKeys.x),
                y: defaults.double(forKey: PositionKeys.y)
            )
            panel.setFrameOrigin(origin)
        } else {
            resetPosition()
        }
    }
}
