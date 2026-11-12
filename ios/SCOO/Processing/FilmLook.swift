import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

enum FilmLook: String, CaseIterable, Identifiable, Codable {
    case warm = "Warm CCD"
    case flash = "Soft Flash"
    case mint = "Mint Day"
    case mono = "Mono 2006"
    var id: String { rawValue }
    var caption: String { switch self { case .warm: "따뜻한 오후"; case .flash: "빛바랜 기억"; case .mint: "초록빛 하루"; case .mono: "흑백의 순간" } }

    func apply(to input: CIImage, finishing: Bool) -> CIImage {
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        switch self {
        case .warm: controls.saturation = 0.82; controls.contrast = 0.94; controls.brightness = 0.025
        case .flash: controls.saturation = 0.65; controls.contrast = 0.88; controls.brightness = 0.09
        case .mint: controls.saturation = 0.65; controls.contrast = 0.93; controls.brightness = 0.035
        case .mono: controls.saturation = 0; controls.contrast = 1.1; controls.brightness = 0.01
        }
        var image = controls.outputImage ?? input
        if self != .mono {
            let tint = CIFilter.temperatureAndTint()
            tint.inputImage = image
            tint.neutral = CIVector(x: self == .warm ? 5800 : 6500, y: self == .mint ? -12 : 0)
            tint.targetNeutral = CIVector(x: 6500, y: 0)
            image = tint.outputImage ?? image
        }
        if finishing {
            let vignette = CIFilter.vignette()
            vignette.inputImage = image
            vignette.intensity = 0.45
            vignette.radius = 1.6
            image = vignette.outputImage ?? image
            if let noise = CIFilter.randomGenerator().outputImage {
                let gray = noise.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                let grain = gray.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0.06, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.06, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0.06, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: -0.03, y: -0.03, z: -0.03, w: 0)
                ]).cropped(to: input.extent)
                image = grain.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: image])
            }
        }
        return image.cropped(to: input.extent)
    }
}
