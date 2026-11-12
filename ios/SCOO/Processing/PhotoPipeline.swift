import UIKit
import CoreImage
import Vision
import Photos

actor PhotoPipeline {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func process(data: Data, look: FilmLook, mode: CaptureMode, dateStamp: Bool, aspectRatio: CGFloat = 3 / 4) throws -> ProcessedPhoto {
        guard let uiImage = UIImage(data: data) else { throw SCOOError.message("사진을 열 수 없어요.") }
        // UIKit normalizes all EXIF orientations before cropping or Vision analysis.
        let size = uiImage.size
        let scale = min(1, 2400 / max(size.width, size.height))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: CGSize(width: size.width * scale, height: size.height * scale), format: format)
            .image { _ in uiImage.draw(in: CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)) }
        guard let cg = normalized.cgImage else { throw SCOOError.message("사진을 변환하지 못했어요.") }
        let original = CIImage(cgImage: cg)
        let targetRatio = min(2, max(0.3, aspectRatio))
        var rect = original.extent
        if rect.width / rect.height > targetRatio {
            let width = rect.height * targetRatio
            rect.origin.x = (rect.width - width) / 2; rect.size.width = width
        } else {
            let height = rect.width / targetRatio
            rect.origin.y = (rect.height - height) / 2; rect.size.height = height
        }
        let cropped = original.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
        guard let analysisImage = context.createCGImage(cropped, from: cropped.extent) else {
            throw SCOOError.message("사진을 분석할 수 없어요.")
        }
        let classification = classify(analysisImage, mode: mode)
        let bonus = quality(analysisImage)
        let result = look.apply(to: cropped, finishing: true)
        guard let rendered = context.createCGImage(result, from: result.extent) else {
            throw SCOOError.message("필터를 적용하지 못했어요.")
        }
        var image = UIImage(cgImage: rendered)
        if dateStamp {
            let formatter = DateFormatter(); formatter.dateFormat = "yy. MM. dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
            image = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(at: .zero)
                let font = UIFont.monospacedSystemFont(ofSize: image.size.width * 0.027, weight: .medium)
                let text = formatter.string(from: Date()) as NSString
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(red: 1, green: 0.75, blue: 0.48, alpha: 0.95)]
                let textSize = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: image.size.width - textSize.width - image.size.width * 0.04,
                                      y: image.size.height - textSize.height - image.size.height * 0.035), withAttributes: attributes)
            }
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.92) else { throw SCOOError.message("JPEG를 만들지 못했어요.") }
        return ProcessedPhoto(jpeg: jpeg, isFood: classification.0, bonus: bonus, classificationNote: classification.1)
    }

    private func classify(_ image: CGImage, mode: CaptureMode) -> (Bool, String) {
        if mode == .food { return (true, "음식 모드를 직접 선택했어요.") }
        if mode == .daily { return (false, "일상 모드를 직접 선택했어요.") }
        do {
            let request = VNClassifyImageRequest()
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            let foodTerms: Set<String> = ["food", "food_and_drink", "food_and_beverage", "meal", "dish", "cuisine", "dessert", "pizza", "pasta", "bread", "cake", "cookie", "sushi", "salad", "soup", "sandwich", "fruit", "vegetable", "coffee", "tea", "beverage", "ice_cream", "chocolate", "pastry", "noodle", "rice", "steak", "hamburger", "seafood"]
            let match = request.results?.prefix(25).first { result in
                let identifier = result.identifier.lowercased().replacingOccurrences(of: " ", with: "_")
                return result.confidence >= 0.25 && foodTerms.contains(where: { term in
                    identifier == term || identifier.hasPrefix(term + "_") || identifier.hasSuffix("_" + term)
                })
            }
            if let match { return (true, "음식 추정 · \(match.identifier) \(Int(match.confidence * 100))%") }
            return (false, "일상으로 분류했어요. 음식이면 촬영 전 음식 모드를 골라 주세요.")
        } catch {
            return (false, "자동 분류를 사용할 수 없어 일상으로 기록했어요.")
        }
    }

    private func quality(_ image: CGImage) -> Int {
        let width = 96, height = 128
        var bytes = [UInt8](repeating: 0, count: width * height)
        let drawn = bytes.withUnsafeMutableBytes { pointer -> Bool in
            guard let ctx = CGContext(data: pointer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? GrowthRules.qualityBonus(luminance: bytes.map(Double.init), width: width, height: height) : 0
    }
}

enum PhotoLibraryWriter {
    static func save(_ data: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SCOOError.message("사진 앱 저장 권한이 꺼져 있어요. 설정 > SCOO > 사진에서 허용해 주세요. 앱 안의 사진은 그대로 보관돼요.")
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }
}
