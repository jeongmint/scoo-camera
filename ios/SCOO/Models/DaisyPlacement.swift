import Foundation
import CoreGraphics

/// Where to pin the adult daisy on a transparent character image. Same rule as tools/breeding/breed.py:
/// find the silhouette, go to `spot.x` across it, take the top edge there (or, with `belowEars`,
/// the top edge below where ears and stems meet the head) and pin the flower slightly into the body.
enum DaisyPlacement {
    /// Flower width as a fraction of the character's width.
    static let widthRatio: CGFloat = 0.26
    /// Counter-clockwise tilt in degrees.
    static let tilt: Double = 12

    struct Result: Equatable {
        /// Flower center in unit coordinates of the image (0...1, origin top-left).
        let center: CGPoint
        /// Flower width as a fraction of the image width.
        let width: CGFloat
    }

    /// `alpha` holds one byte per pixel, row by row from the top.
    static func place(alpha: [UInt8], width: Int, height: Int, spot: DaisySpot) -> Result? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        func solid(_ x: Int, _ y: Int) -> Bool { alpha[y * width + x] > 128 }
        var left = width, right = -1, top = height, bottom = -1
        for y in 0..<height {
            for x in 0..<width where solid(x, y) {
                left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
            }
        }
        guard right >= left, bottom >= top else { return nil }
        let span = right - left + 1
        let x = min(right, max(left, left + Int((CGFloat(span) * spot.x).rounded(.down))))
        var floor = top
        if spot.belowEars {
            // first row where the silhouette is a single piece at least 40% as wide as the character
            for y in top...bottom {
                let row = (left...right).filter { solid($0, y) }
                if let first = row.first, let last = row.last, last - first + 1 == row.count, CGFloat(row.count) >= CGFloat(span) * 0.4 {
                    floor = y
                    break
                }
            }
        }
        let edge = (floor...bottom).first { solid(x, $0) } ?? floor
        let flower = CGFloat(span) * widthRatio
        // the tilted flower is about 10% taller than wide; pin it a little into the body
        let centerY = CGFloat(edge) + flower * 1.1 * (0.12 + spot.drop)
        return Result(center: CGPoint(x: CGFloat(x) / CGFloat(width), y: centerY / CGFloat(height)),
                      width: flower / CGFloat(width))
    }

    /// Reads the image's alpha at a small size and places the flower.
    static func place(on image: CGImage, spot: DaisySpot, sample: Int = 200) -> Result? {
        let width = sample, height = max(1, Int((CGFloat(sample) * CGFloat(image.height) / CGFloat(max(1, image.width))).rounded()))
        var bytes = [UInt8](repeating: 0, count: width * height)
        let drawn = bytes.withUnsafeMutableBytes { pointer -> Bool in
            guard let context = CGContext(data: pointer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? place(alpha: bytes, width: width, height: height, spot: spot) : nil
    }
}
