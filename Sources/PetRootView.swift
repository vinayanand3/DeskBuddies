import SwiftUI
import AppKit

private enum PetExpression {
    case idle
    case delighted
    case wink
    case annoyed
    case relaxed

    func assetName(default defaultAssetName: String, heatLevel: Int, profile: PetProfile) -> String {
        guard heatLevel == 0 else { return defaultAssetName }
        switch self {
        case .idle: return defaultAssetName
        case .delighted: return profile.assetName(from: "TempurrDelighted")
        case .wink: return profile.assetName(from: "TempurrWink")
        case .annoyed: return profile.assetName(from: "TempurrAnnoyed")
        case .relaxed: return profile.assetName(from: "TempurrRelaxed")
        }
    }
}

struct PetRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var thermalMonitor: ThermalMonitor
    @ObservedObject var settings: PetSettings
    @ObservedObject var motionModel: PetMotionModel
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onInteraction: () -> Void

    @State private var bounce: CGFloat = 0
    @State private var squash: CGFloat = 1
    @State private var rotation: Double = 0
    @State private var tailWag = false
    @State private var showHeart = false
    @State private var reactionText = ""
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var expression: PetExpression = .idle
    @State private var pokeCount = 0
    @State private var lastPokeAt = Date.distantPast
    @State private var expressionResetWorkItem: DispatchWorkItem?
    @State private var heartResetWorkItem: DispatchWorkItem?
    @State private var textResetWorkItem: DispatchWorkItem?
    @State private var lastScratchPoint: CGPoint?
    @State private var lastScratchAt = Date.distantPast
    @State private var scratchDistance: CGFloat = 0
    @State private var scratchDirection: CGFloat = 0
    @State private var scratchReversals = 0

    private var heatLevel: Int {
        switch thermalMonitor.effectiveState(previewMode: settings.thermalPreview) {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 0
        }
    }

    var body: some View {
        let presentation = thermalMonitor.presentation(previewMode: settings.thermalPreview)
        let scaledSide = 220 * settings.catScale
        let showsAutonomousMotion = expression == .idle && motionModel.activity != .idle
        let defaultAssetName = settings.petProfile.assetName(from: presentation.assetName)
        let motionPolicy = ThermalMotionPolicy.policy(
            for: thermalMonitor.effectiveState(previewMode: settings.thermalPreview)
        )
        let petAssetName = showsAutonomousMotion
            ? settings.petProfile.assetName(
                from: motionModel.assetName(thermalSuffix: motionPolicy.animationAssetSuffix)
            )
            : expression.assetName(
                default: defaultAssetName,
                heatLevel: heatLevel,
                profile: settings.petProfile
            )

        ZStack {
            if settings.showBubble {
                ThermalBubble(presentation: presentation)
                    .position(x: 110, y: 32)
                    .transition(.scale.combined(with: .opacity))
            }

            if showHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.pink)
                    .position(x: 174, y: 76)
                    .transition(.scale.combined(with: .opacity))
            }

            if !reactionText.isEmpty {
                Text(reactionText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .position(x: 49, y: 79)
                    .transition(.scale.combined(with: .opacity))
            }

            PetIllustration(
                assetName: petAssetName,
                profile: settings.petProfile,
                breathing: !showsAutonomousMotion && tailWag,
                heatLevel: heatLevel,
                isHovering: isHovering,
                mirrored: showsAutonomousMotion && motionModel.facingLeft,
                animateAssetChanges: !showsAutonomousMotion
            )
            .frame(width: 148, height: 148)
            .scaleEffect(x: 1, y: squash, anchor: .bottom)
            .scaleEffect(isPressed ? 0.94 : 1, anchor: .bottom)
            .rotationEffect(.degrees(rotation))
            .offset(y: 39 + bounce + (isPressed ? 3 : 0))
            .contentShape(Rectangle())
            .onTapGesture(perform: reactToTap)
            .onLongPressGesture(
                minimumDuration: 10,
                maximumDistance: 8,
                pressing: { pressing in
                    withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
                        isPressed = pressing
                    }
                },
                perform: {}
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active: trackScratch(at: NSEvent.mouseLocation)
                case .ended: resetScratchTracking()
                }
            }
            .help("Click to play, rub back and forth to scratch, or drag to move your DeskBuddy.")
        }
        .frame(width: 220, height: 220)
        .scaleEffect(settings.catScale)
        .frame(width: scaledSide, height: scaledSide)
        .background(Color.clear)
        .simultaneousGesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { value in
                    onDragChanged(value.translation)
                }
                .onEnded { _ in
                    onDragEnded()
                }
        )
        .task(id: idleAnimationEnabled) {
            tailWag = false
            guard idleAnimationEnabled else { return }
            await runIdleAnimationLoop()
        }
        .onReceive(settings.$scratchRequestCount.dropFirst()) { _ in
            reactToScratch()
        }
    }

    private func trackScratch(at location: CGPoint) {
        let now = Date()
        if now.timeIntervalSince(lastScratchAt) > 0.32 {
            resetScratchTracking()
        }
        defer {
            lastScratchPoint = location
            lastScratchAt = now
        }

        guard let previous = lastScratchPoint else { return }
        let dx = location.x - previous.x
        let dy = location.y - previous.y
        let distance = hypot(dx, dy)
        guard distance >= 2, distance < 55 else { return }

        scratchDistance += distance
        if abs(dx) >= 2.5 {
            let direction: CGFloat = dx > 0 ? 1 : -1
            if scratchDirection != 0, direction != scratchDirection {
                scratchReversals += 1
            }
            scratchDirection = direction
        }

        if scratchDistance >= 85, scratchReversals >= 2 {
            reactToScratch()
            resetScratchTracking()
        }
    }

    private func resetScratchTracking() {
        lastScratchPoint = nil
        scratchDistance = 0
        scratchDirection = 0
        scratchReversals = 0
    }

    private func reactToScratch() {
        onInteraction()
        expression = .relaxed
        pokeCount = 0
        hideHeart()
        showTemporaryText("Prrrr…")
        performRelaxedPulse()
        if settings.soundEnabled {
            CatSoundPlayer.shared.play(.purr)
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        scheduleExpressionReset(after: 2.2)
    }

    private var idleAnimationEnabled: Bool {
        motionModel.animationsEnabled
            && motionModel.activity == .idle
            && expression == .idle
            && !reduceMotion
    }

    private func runIdleAnimationLoop() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 18_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.42)) {
                tailWag = true
            }

            do {
                try await Task.sleep(nanoseconds: 480_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.42)) {
                tailWag = false
            }
        }
    }

    private func reactToTap() {
        onInteraction()
        let now = Date()
        if now.timeIntervalSince(lastPokeAt) > 1.35 {
            pokeCount = 0
        }
        lastPokeAt = now
        pokeCount += 1
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        switch pokeCount {
        case 1:
            if settings.soundEnabled {
                CatSoundPlayer.shared.play(primaryTouchSound)
            }
            expression = .delighted
            performJump()
            showTemporaryHeart()
            showTemporaryText(primaryTouchText)
        case 2...3:
            if settings.soundEnabled {
                CatSoundPlayer.shared.play(.chirp)
            }
            expression = .wink
            performTilt()
            showTemporaryHeart()
            showTemporaryText("Hehe!")
        default:
            if settings.soundEnabled {
                CatSoundPlayer.shared.play(.grumble)
            }
            expression = .annoyed
            hideHeart()
            performAnnoyedShake()
            showTemporaryText("Hey!")
        }

        scheduleExpressionReset()
    }

    private var primaryTouchSound: CatSoundPlayer.Sound {
        switch settings.petProfile {
        case .cat: return .meow
        case .dog: return .bark
        case .sloth, .panda: return .chirp
        }
    }

    private var primaryTouchText: String {
        switch settings.petProfile {
        case .cat: return "Purr!"
        case .dog: return "Woof!"
        case .sloth: return "Mmm!"
        case .panda: return "Yay!"
        }
    }

    private func performJump() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            bounce = -24
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                bounce = 0
            }
        }
    }

    private func performSquish() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.16, dampingFraction: 0.48)) {
            squash = 0.82
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.48)) {
                squash = 1
            }
        }
    }

    private func performTilt() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            rotation = -8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                rotation = 0
            }
        }
    }

    private func performWiggle() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.08).repeatCount(5, autoreverses: true)) {
            rotation = 5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            rotation = 0
        }
    }

    private func performAnnoyedShake() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.055).repeatCount(7, autoreverses: true)) {
            rotation = 4.5
        }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            squash = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                rotation = 0
                squash = 1
            }
        }
    }

    private func performRelaxedPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.38).repeatCount(3, autoreverses: true)) {
            squash = 0.94
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.easeOut(duration: 0.22)) {
                squash = 1
            }
        }
    }

    private func scheduleExpressionReset(after delay: TimeInterval = 1.65) {
        expressionResetWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                expression = .idle
                pokeCount = 0
            }
        }
        expressionResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func showTemporaryHeart() {
        heartResetWorkItem?.cancel()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
            showHeart = true
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.2)) {
                showHeart = false
            }
        }
        heartResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68, execute: workItem)
    }

    private func hideHeart() {
        heartResetWorkItem?.cancel()
        withAnimation(.easeOut(duration: 0.12)) {
            showHeart = false
        }
    }

    private func showTemporaryText(_ text: String) {
        textResetWorkItem?.cancel()
        withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
            reactionText = text
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.18)) {
                reactionText = ""
            }
        }
        textResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: workItem)
    }
}

private struct ThermalBubble: View {
    let presentation: ThermalPresentation

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.regularMaterial)
                .frame(width: 13, height: 13)
                .rotationEffect(.degrees(45))
                .offset(y: 5)
                .shadow(color: .black.opacity(0.1), radius: 3, y: 2)

            HStack(spacing: 9) {
                Image(systemName: presentation.symbol)
                    .foregroundStyle(presentation.color)
                    .font(.system(size: 14, weight: .semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text(presentation.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(presentation.detail)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
    }
}
