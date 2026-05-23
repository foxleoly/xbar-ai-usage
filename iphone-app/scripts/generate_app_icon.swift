import AppKit
import CoreGraphics
import Foundation

struct IconVariant {
    let filename: String
    let pixels: Int
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppHost/Assets.xcassets/AppIcon.appiconset")
let variants = [
    IconVariant(filename: "AppIcon-20@2x.png", pixels: 40),
    IconVariant(filename: "AppIcon-20@3x.png", pixels: 60),
    IconVariant(filename: "AppIcon-29@2x.png", pixels: 58),
    IconVariant(filename: "AppIcon-29@3x.png", pixels: 87),
    IconVariant(filename: "AppIcon-40@2x.png", pixels: 80),
    IconVariant(filename: "AppIcon-40@3x.png", pixels: 120),
    IconVariant(filename: "AppIcon-60@2x.png", pixels: 120),
    IconVariant(filename: "AppIcon-60@3x.png", pixels: 180),
    IconVariant(filename: "AppIcon-1024.png", pixels: 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawLinearGradient(
    in context: CGContext,
    rect: CGRect,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
        return
    }
    context.saveGState()
    context.clip(to: rect)
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

func drawRadialGradient(
    in context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    colors: [CGColor],
    locations: [CGFloat]
) {
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
        return
    }
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
}

func renderIconPNG(size: Int) throws -> Data {
    let side = CGFloat(size)
    let scale = side / 1024
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else {
        throw NSError(domain: "TokenDockIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context"])
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    context.scaleBy(x: scale, y: scale)

    let bounds = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    context.setFillColor(color(0.006, 0.008, 0.011))
    context.fill(bounds)

    drawLinearGradient(
        in: context,
        rect: bounds,
        colors: [
            color(0.055, 0.082, 0.105),
            color(0.016, 0.023, 0.030),
            color(0.006, 0.008, 0.011)
        ],
        locations: [0, 0.58, 1],
        start: CGPoint(x: 120, y: 930),
        end: CGPoint(x: 880, y: 70)
    )

    drawRadialGradient(
        in: context,
        center: CGPoint(x: 352, y: 720),
        radius: 390,
        colors: [color(0.09, 0.88, 0.72, 0.24), color(0.09, 0.88, 0.72, 0)],
        locations: [0, 1]
    )

    drawRadialGradient(
        in: context,
        center: CGPoint(x: 760, y: 235),
        radius: 430,
        colors: [color(0.18, 0.32, 0.42, 0.42), color(0.18, 0.32, 0.42, 0)],
        locations: [0, 1]
    )

    let glassRect = CGRect(x: 252, y: 250, width: 520, height: 520)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -26), blur: 54, color: color(0, 0, 0, 0.36))
    context.addPath(roundedRect(glassRect, radius: 172))
    context.clip()
    drawLinearGradient(
        in: context,
        rect: glassRect,
        colors: [
            color(1, 1, 1, 0.145),
            color(1, 1, 1, 0.058),
            color(1, 1, 1, 0.026)
        ],
        locations: [0, 0.46, 1],
        start: CGPoint(x: glassRect.midX, y: glassRect.maxY),
        end: CGPoint(x: glassRect.midX, y: glassRect.minY)
    )
    context.restoreGState()

    context.saveGState()
    context.addPath(roundedRect(glassRect, radius: 172))
    context.setStrokeColor(color(1, 1, 1, 0.14))
    context.setLineWidth(5)
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setLineCap(.round)
    context.setLineWidth(34)
    context.setStrokeColor(color(1, 1, 1, 0.115))
    context.addArc(center: CGPoint(x: 512, y: 510), radius: 182, startAngle: 0.24 * .pi, endAngle: 1.82 * .pi, clockwise: false)
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setLineCap(.round)
    context.setLineWidth(32)
    context.setStrokeColor(color(0.09, 0.88, 0.72, 0.84))
    context.setShadow(offset: .zero, blur: 24, color: color(0.09, 0.88, 0.72, 0.18))
    context.addArc(center: CGPoint(x: 512, y: 510), radius: 128, startAngle: 0.88 * .pi, endAngle: 2.22 * .pi, clockwise: false)
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setLineCap(.round)
    context.setLineWidth(26)
    context.setStrokeColor(color(1, 1, 1, 0.34))
    context.addArc(center: CGPoint(x: 512, y: 510), radius: 76, startAngle: 0.98 * .pi, endAngle: 2.04 * .pi, clockwise: false)
    context.strokePath()
    context.restoreGState()

    context.saveGState()
    context.setShadow(offset: .zero, blur: 20, color: color(1, 1, 1, 0.08))
    context.setFillColor(color(1, 1, 1, 0.92))
    context.fillEllipse(in: CGRect(x: 490, y: 488, width: 44, height: 44))
    context.restoreGState()

    guard let cgImage = context.makeImage() else {
        throw NSError(domain: "TokenDockIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not render icon image"])
    }

    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "TokenDockIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }

    return png
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for variant in variants {
    let png = try renderIconPNG(size: variant.pixels)
    try png.write(to: outputDirectory.appendingPathComponent(variant.filename))
}
