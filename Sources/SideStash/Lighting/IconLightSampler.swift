import AppKit

/// Tuning for how a file icon turns into a light source.
enum IconLightStyle {
    static let samplePixels = 6
    /// Saturation-weighted color an icon needs before it emits colored light.
    static let colorfulWeightThreshold: CGFloat = 0.25
    /// Color weight at which an icon emits at full strength.
    static let fullStrengthWeight: CGFloat = 6
    static let minStrength: CGFloat = 0.6
    static let minLightSaturation: CGFloat = 0.4
    static let maxLightSaturation: CGFloat = 0.75
    /// Red reads much stronger than other hues at the same saturation, so hues
    /// within `redHueBand.lowerBound` of pure red are capped lower, easing back
    /// to the general cap by `redHueBand.upperBound`.
    static let maxRedLightSaturation: CGFloat = 0.5
    static let redHueBand: ClosedRange<CGFloat> = 0.05...0.08

    static func maxSaturation(forHue hue: CGFloat) -> CGFloat {
        let distanceFromRed = min(hue, 1 - hue)
        if distanceFromRed <= redHueBand.lowerBound {
            return maxRedLightSaturation
        }
        if distanceFromRed >= redHueBand.upperBound {
            return maxLightSaturation
        }
        let progress = (distanceFromRed - redHueBand.lowerBound)
            / (redHueBand.upperBound - redHueBand.lowerBound)
        return maxRedLightSaturation + (maxLightSaturation - maxRedLightSaturation) * progress
    }

    /// More color, more light: from `minStrength` at the threshold up to 1.
    static func strength(forColorWeight weight: CGFloat) -> CGFloat {
        let span = fullStrengthWeight - colorfulWeightThreshold
        let progress = min(max((weight - colorfulWeightThreshold) / span, 0), 1)
        return minStrength + (1 - minStrength) * progress
    }
}

enum IconLightSampler {
    /// The icon's light, or `nil` for icons with too little color (plain
    /// documents, archives) — those emit nothing.
    ///
    /// Pixels are weighted by saturation, so a white document with a red badge
    /// emits red instead of a washed-out average.
    static func light(from icon: NSImage) -> IconLight? {
        let pixels = IconLightStyle.samplePixels
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: pixels,
                  height: pixels,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        context.interpolationQuality = .high

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current?.imageInterpolation = .high
        icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var totalWeight: CGFloat = 0
        for y in 0..<pixels {
            for x in 0..<pixels {
                let offset = y * context.bytesPerRow + x * 4
                let alpha = CGFloat(data[offset + 3]) / 255
                guard alpha > 0.05 else { continue }

                let pixel = NSColor(
                    srgbRed: CGFloat(data[offset]) / 255 / alpha,
                    green: CGFloat(data[offset + 1]) / 255 / alpha,
                    blue: CGFloat(data[offset + 2]) / 255 / alpha,
                    alpha: 1
                )
                let saturation = pixel.saturationComponent
                let weight = alpha * saturation * saturation * pixel.brightnessComponent
                red += pixel.redComponent * weight
                green += pixel.greenComponent * weight
                blue += pixel.blueComponent * weight
                totalWeight += weight
            }
        }

        guard totalWeight >= IconLightStyle.colorfulWeightThreshold else { return nil }

        let average = NSColor(
            srgbRed: red / totalWeight,
            green: green / totalWeight,
            blue: blue / totalWeight,
            alpha: 1
        )
        // Emitted light is bright and softly hued, whatever the icon's shading.
        let hue = average.hueComponent
        let saturation = min(
            max(average.saturationComponent, IconLightStyle.minLightSaturation),
            IconLightStyle.maxSaturation(forHue: hue)
        )
        let color = NSColor(colorSpace: .sRGB, hue: hue, saturation: saturation, brightness: 1, alpha: 1)
        guard let light = LightRGB(color) else { return nil }
        return IconLight(color: light, strength: IconLightStyle.strength(forColorWeight: totalWeight))
    }
}
