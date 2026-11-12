import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

enum FilmLook: String, CaseIterable, Identifiable, Codable {
    case eternal = "Eternal"
    var id: String { rawValue }

    func apply(to input: CIImage, finishing: Bool) -> CIImage {
        // Use a defined sRGB LUT space so neutral reference grays don't shift with the device profile.
        var image = input.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": EternalPalette.dimension,
            "inputCubeData": EternalPalette.cubeData,
            "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB)!
        ])
        let pixelScale = max(input.extent.width, input.extent.height) / 1600
        let glow = CIFilter.bloom()
        glow.inputImage = image.clampedToExtent()
        glow.radius = Float(3.2 * pixelScale)
        glow.intensity = 0.045
        image = (glow.outputImage ?? image).cropped(to: input.extent)

        if finishing {
            // Very slight CCD-like rolloff. Do not turn skin into a smoothed portrait preset.
            // Clean up sensor noise first so the only texture left is the fine grain added below.
            image = image.clampedToExtent().applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.02, "inputSharpness": 0.3]).cropped(to: input.extent)
            image = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.23 * pixelScale]).cropped(to: input.extent)
            if let noise = CIFilter.randomGenerator().outputImage {
                let monoNoise = noise.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.25])
                let grain = monoNoise.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0.012, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.012, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0.014, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: -0.006, y: -0.006, z: -0.007, w: 0)
                ]).cropped(to: input.extent)
                let noisy = grain.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: image])
                let shadowMask = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                    .applyingFilter("CIColorInvert")
                image = noisy.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: shadowMask])
            }
        }
        return image.cropped(to: input.extent)
    }
}
