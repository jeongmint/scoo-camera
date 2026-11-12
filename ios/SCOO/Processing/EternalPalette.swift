import Foundation

/// The single Eternal look: dense blacks, cool neutral shadows, warm light, quiet greens.
/// Palette approximation from the reference mood, not a calibrated Canon camera profile.
enum EternalPalette {
    struct RGB: Equatable {
        var r: Double
        var g: Double
        var b: Double
    }
    static let dimension = 32

    static func smoothstep(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }

    static func curve(_ value: Double) -> Double {
        let x = [0.0, 0.025, 0.09, 0.22, 0.50, 0.78, 0.93, 1.0]
        let y = [0.0, 0.012, 0.055, 0.17, 0.47, 0.79, 0.94, 0.985]
        let v = min(1, max(0, value))
        for i in 1..<x.count where v <= x[i] {
            let t = (v - x[i - 1]) / (x[i] - x[i - 1])
            return y[i - 1] + (y[i] - y[i - 1]) * t
        }
        return y.last!
    }

    static func map(_ input: RGB) -> RGB {
        let luma = input.r * 0.2126 + input.g * 0.7152 + input.b * 0.0722
        // Preserve saturated lamps and signs, while making low-chroma surfaces quieter.
        let chroma = max(input.r, max(input.g, input.b)) - min(input.r, min(input.g, input.b))
        let saturation = 0.93 + 0.06 * smoothstep(0.15, 0.55, chroma)
        var r = curve(luma + (input.r - luma) * saturation)
        var g = curve(luma + (input.g - luma) * saturation)
        var b = curve(luma + (input.b - luma) * saturation)
        let shadow = (1 - smoothstep(0.12, 0.55, luma)) * smoothstep(0, 0.06, luma)
        let light = smoothstep(0.42, 0.93, luma)
        // Keep highlights close to neutral: a stronger warm push reads as a yellow cast on white.
        r += -0.004 * shadow + 0.004 * light
        g += 0.002 * shadow + 0.002 * light
        b += 0.009 * shadow - 0.001 * light
        let green = smoothstep(0.015, 0.12, input.g - max(input.r, input.b))
        r += green * 0.004
        g -= green * 0.004
        b -= green * 0.002
        return RGB(r: min(1, max(0, r)), g: min(1, max(0, g)), b: min(1, max(0, b)))
    }

    /// CIColorCube requires premultiplied float RGBA, red varying fastest.
    static let cubeData: Data = {
        var values = [Float]()
        values.reserveCapacity(dimension * dimension * dimension * 4)
        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    let divisor = Double(dimension - 1)
                    let color = map(RGB(r: Double(red) / divisor, g: Double(green) / divisor, b: Double(blue) / divisor))
                    values.append(contentsOf: [Float(color.r), Float(color.g), Float(color.b), 1])
                }
            }
        }
        return values.withUnsafeBytes { Data($0) }
    }()
}
