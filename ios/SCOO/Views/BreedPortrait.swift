import SwiftUI
import UIKit
import CoreImage

/// Shows a baby or an adult. Uses the drawn baby (`Breed-a-b`) when it exists; otherwise a stand-in:
/// parent A's shape painted in parent B's main color. Adults get a daisy, from `Adult-a-b` if drawn,
/// or pinned on the fly with the same rule as the breeding tool.
struct BreedPortrait: View {
    let breed: Breed
    var adult = false

    var body: some View {
        if adult, let drawn = UIImage(named: breed.adultAsset) {
            Image(uiImage: drawn).resizable().scaledToFit()
        } else if let baby = UIImage(named: breed.babyAsset) {
            DaisyFrame(image: baby, key: breed.babyAsset, spot: breed.mother?.daisy ?? DaisySpot(), adult: adult) {
                Image(uiImage: baby).resizable().scaledToFit()
            }
        } else if let mother = breed.mother, let shape = UIImage(named: mother.assetName) {
            DaisyFrame(image: shape, key: mother.assetName, spot: mother.daisy, adult: adult) {
                StandInBaby(shape: shape, color: breed.father.flatMap { BodyColor.of($0.assetName) } ?? .white)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("임시 그림").font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.white.opacity(0.8), in: Capsule()).foregroundStyle(.secondary)
            }
        } else {
            Image(systemName: "questionmark.circle").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }
}

/// A plain species portrait (for parent pickers).
struct SpeciesPortrait: View {
    let species: Species
    var body: some View {
        if let image = UIImage(named: species.assetName) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "questionmark.circle").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }
}

/// Wraps a square character image and pins the daisy on adults.
private struct DaisyFrame<Content: View>: View {
    let image: UIImage
    /// Asset name, used to remember the computed spot.
    let key: String
    let spot: DaisySpot
    let adult: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if adult, let cg = image.cgImage, let place = DaisyCache.place(cg, key: key, spot: spot) {
                    GeometryReader { proxy in
                        Image("Daisy").resizable().scaledToFit()
                            .frame(width: proxy.size.width * place.width)
                            .rotationEffect(.degrees(-DaisyPlacement.tilt))
                            .position(x: proxy.size.width * place.center.x, y: proxy.size.height * place.center.y)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

/// Parent A's silhouette and shading in parent B's color.
private struct StandInBaby: View {
    let shape: UIImage
    let color: Color
    var body: some View {
        Image(uiImage: shape).resizable().scaledToFit()
            .grayscale(1)
            .brightness(0.12)
            .colorMultiply(color)
    }
}

/// Small caches so lists of babies do not repeat the pixel work.
@MainActor
private enum DaisyCache {
    static var results: [String: DaisyPlacement.Result] = [:]
    static func place(_ image: CGImage, key name: String, spot: DaisySpot) -> DaisyPlacement.Result? {
        let key = "\(name)-\(spot.x)-\(spot.belowEars)-\(spot.drop)"
        if let hit = results[key] { return hit }
        let result = DaisyPlacement.place(on: image, spot: spot)
        results[key] = result
        return result
    }
}

/// The average color of a character's visible pixels, used as its "main color".
@MainActor
enum BodyColor {
    private static var cache: [String: Color] = [:]
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func of(_ assetName: String) -> Color? {
        if let hit = cache[assetName] { return hit }
        guard let image = UIImage(named: assetName), let input = CIImage(image: image),
              let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)]),
              let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: output.extent, format: .RGBA8, colorSpace: nil)
        let alpha = Double(pixel[3]) / 255
        guard alpha > 0.01 else { return nil }
        // the average includes transparent pixels (premultiplied); divide them back out
        let color = Color(red: min(1, Double(pixel[0]) / 255 / alpha),
                          green: min(1, Double(pixel[1]) / 255 / alpha),
                          blue: min(1, Double(pixel[2]) / 255 / alpha))
        cache[assetName] = color
        return color
    }
}
