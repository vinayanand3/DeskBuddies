import SwiftUI
import AppKit

struct PetIllustration: View {
    private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 24
        return cache
    }()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let assetName: String
    let profile: PetProfile
    let breathing: Bool
    let heatLevel: Int
    let isHovering: Bool
    let mirrored: Bool
    let animateAssetChanges: Bool

    var body: some View {
        ZStack {
            petImage
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .id(assetName)
                .scaleEffect(
                    x: mirrored ? -breathingScale : breathingScale,
                    y: breathingScale,
                    anchor: .bottom
                )
                .shadow(color: .black.opacity(0.14), radius: 5, y: 4)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))

            if isHovering {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: -61, y: -55)
                    .transition(.scale.combined(with: .opacity))
            }

            if heatLevel >= 2 {
                Image(systemName: "drop.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .offset(x: 61, y: -50)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isHovering)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: heatLevel)
        .animation(
            reduceMotion || !animateAssetChanges ? nil : .spring(response: 0.22, dampingFraction: 0.78),
            value: assetName
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("DeskBuddies desktop \(profile.rawValue.lowercased())")
        .accessibilityHint("Click to play with your DeskBuddy")
    }

    private var breathingScale: CGFloat {
        !reduceMotion && breathing ? 1.012 : 1
    }

    private var petImage: Image {
        if let cachedImage = Self.imageCache.object(forKey: assetName as NSString) {
            return Image(nsImage: cachedImage)
        }

#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle.main
#endif

        guard let url = bundle.url(forResource: assetName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return Image(systemName: "cat.fill")
        }
        Self.imageCache.setObject(image, forKey: assetName as NSString)
        return Image(nsImage: image)
    }
}
