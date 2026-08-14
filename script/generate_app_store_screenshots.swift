import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Sources/Resources")
let output = root.appendingPathComponent("AppStore/Screenshots")
let canvasSize = NSSize(width: 2880, height: 1800)

struct Buddy {
    let name: String
    let asset: String
    let accent: NSColor
}

func image(named name: String) -> NSImage {
    guard let result = NSImage(contentsOf: resources.appendingPathComponent(name)) else {
        fatalError("Missing resource: \(name)")
    }
    return result
}

func roundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func text(_ value: String, at point: NSPoint, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left, width: CGFloat = 2400) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    value.draw(
        in: NSRect(x: point.x, y: point.y, width: width, height: font.pointSize * 1.45),
        withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]
    )
}

func drawSprite(_ sprite: NSImage, in rect: NSRect) {
    sprite.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
}

func render(name: String, draw: () -> Void) {
    let result = NSImage(size: canvasSize)
    result.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    result.unlockFocus()

    guard let resized = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvasSize.width),
            pixelsHigh: Int(canvasSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else { fatalError("Could not render \(name)") }
    resized.size = canvasSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resized)
    result.draw(in: NSRect(origin: .zero, size: canvasSize))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = resized.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(name)")
    }
    try! png.write(to: output.appendingPathComponent(name))
}

let ink = NSColor(calibratedWhite: 0.12, alpha: 1)
let secondary = NSColor(calibratedWhite: 0.38, alpha: 1)
let background = NSColor(calibratedRed: 0.96, green: 0.975, blue: 0.98, alpha: 1)
let titleFont = NSFont.systemFont(ofSize: 116, weight: .bold)
let subtitleFont = NSFont.systemFont(ofSize: 50, weight: .medium)
let cardTitleFont = NSFont.systemFont(ofSize: 48, weight: .semibold)

render(name: "03-meet-the-buddies.png") {
    background.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()
    text("Meet your DeskBuddies", at: NSPoint(x: 240, y: 1540), font: titleFont, color: ink)
    text("Choose the companion that makes your desktop feel like home.", at: NSPoint(x: 245, y: 1450), font: subtitleFont, color: secondary)

    let buddies = [
        Buddy(name: "Cat", asset: "TempurrNominal.png", accent: NSColor(calibratedRed: 0.25, green: 0.82, blue: 0.72, alpha: 1)),
        Buddy(name: "Dog", asset: "TempurrDogFair.png", accent: NSColor(calibratedRed: 0.97, green: 0.76, blue: 0.27, alpha: 1)),
        Buddy(name: "Panda", asset: "TempurrPandaSerious.png", accent: NSColor(calibratedRed: 0.98, green: 0.50, blue: 0.20, alpha: 1)),
        Buddy(name: "Sloth", asset: "TempurrSlothCritical.png", accent: NSColor(calibratedRed: 0.91, green: 0.27, blue: 0.31, alpha: 1)),
    ]

    for (index, buddy) in buddies.enumerated() {
        let x = 230 + CGFloat(index) * 660
        let card = NSRect(x: x, y: 240, width: 590, height: 1080)
        NSShadow().apply {
            $0.shadowColor = NSColor.black.withAlphaComponent(0.12)
            $0.shadowBlurRadius = 30
            $0.shadowOffset = NSSize(width: 0, height: -8)
            roundedRect(card, radius: 58, color: .white)
        }
        roundedRect(NSRect(x: x + 54, y: 316, width: 482, height: 18), radius: 9, color: buddy.accent)
        drawSprite(image(named: buddy.asset), in: NSRect(x: x + 40, y: 500, width: 510, height: 510))
        text(buddy.name, at: NSPoint(x: x + 40, y: 385), font: cardTitleFont, color: ink, alignment: .center, width: 510)
    }
}

render(name: "04-thermal-personalities.png") {
    NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.14, alpha: 1).setFill()
    NSRect(origin: .zero, size: canvasSize).fill()
    text("A buddy that feels your Mac", at: NSPoint(x: 240, y: 1540), font: titleFont, color: .white)
    text("Apple's supported thermal states become expressive colors and motion.", at: NSPoint(x: 245, y: 1450), font: subtitleFont, color: NSColor.white.withAlphaComponent(0.72))

    let states = [
        Buddy(name: "Cool", asset: "TempurrNominal.png", accent: NSColor(calibratedRed: 0.25, green: 0.82, blue: 0.72, alpha: 1)),
        Buddy(name: "Warm", asset: "TempurrFair.png", accent: NSColor(calibratedRed: 0.97, green: 0.78, blue: 0.25, alpha: 1)),
        Buddy(name: "Hot", asset: "TempurrSerious.png", accent: NSColor(calibratedRed: 0.98, green: 0.49, blue: 0.18, alpha: 1)),
        Buddy(name: "Critical", asset: "TempurrCritical.png", accent: NSColor(calibratedRed: 0.93, green: 0.24, blue: 0.28, alpha: 1)),
    ]

    for (index, state) in states.enumerated() {
        let x = 230 + CGFloat(index) * 660
        let card = NSRect(x: x, y: 240, width: 590, height: 1080)
        roundedRect(card, radius: 58, color: NSColor.white.withAlphaComponent(0.08))
        roundedRect(NSRect(x: x + 54, y: 316, width: 482, height: 18), radius: 9, color: state.accent)
        drawSprite(image(named: state.asset), in: NSRect(x: x + 40, y: 500, width: 510, height: 510))
        text(state.name, at: NSPoint(x: x + 40, y: 385), font: cardTitleFont, color: .white, alignment: .center, width: 510)
    }
}

extension NSShadow {
    func apply(_ body: (NSShadow) -> Void) {
        NSGraphicsContext.saveGraphicsState()
        body(self)
        set()
        NSGraphicsContext.restoreGraphicsState()
    }
}
