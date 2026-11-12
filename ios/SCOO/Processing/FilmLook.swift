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
            image = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.23 * pixelScale]).cropped(to: input.extent)
            if let noise = CIFilter.randomGenerator().outputImage {
                let monoNoise = noise.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.25])
                let grain = monoNoise.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0.035, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.035, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0.042, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: -0.0175, y: -0.0175, z: -0.021, w: 0)
                ]).cropped(to: input.extent)
                let noisy = grain.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: image])
                let shadowMask = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                    .applyingFilter("CIColorInvert")
                image = noisy.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: shadowMask])
            }
            let vignette = CIFilter.vignette()
            vignette.inputImage = image
            vignette.intensity = 0.15
            vignette.radius = 1.8
            image = vignette.outputImage ?? image
        }
        return image.cropped(to: input.extent)
    }
}
