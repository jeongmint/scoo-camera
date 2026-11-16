import AVFoundation
import CoreImage
import UIKit

/// A short silent video made from the same filtered frames the preview shows (so it has the Eternal look).
/// Lives on the camera's frame queue.
final class ClipWriter {
    struct Clip {
        let url: URL
        /// The first frame as a JPEG, used as the album thumbnail.
        let poster: Data
        let seconds: Double
    }

    static let maxSeconds = 15.0

    let url: URL
    let size: CGSize
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let context: CIContext
    private var firstTime: CMTime?
    private var lastTime: CMTime?
    private var poster: CGImage?

    /// `size` is the frame size of the first frame, scaled down so the long side is at most 1920 px.
    init(firstFrame extent: CGRect, context: CIContext) throws {
        let scale = min(1, 1920 / max(extent.width, extent.height))
        // encoders want even dimensions
        let width = Int(extent.width * scale) / 2 * 2, height = Int(extent.height * scale) / 2 * 2
        size = CGSize(width: width, height: height)
        url = FileManager.default.temporaryDirectory.appendingPathComponent("scoo-\(UUID().uuidString).mov")
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw SCOOError.message("동영상을 준비하지 못했어요.") }
        writer.add(input)
        self.context = context
    }

    var seconds: Double {
        guard let firstTime, let lastTime else { return 0 }
        return CMTimeGetSeconds(CMTimeSubtract(lastTime, firstTime))
    }

    func append(_ image: CIImage, at time: CMTime) {
        if firstTime == nil {
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: time)
            firstTime = time
        }
        guard writer.status == .writing, input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return }
        let frame = fit(image)
        context.render(frame, to: buffer, bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        if poster == nil { poster = context.createCGImage(frame, from: CGRect(origin: .zero, size: size)) }
        if adaptor.append(buffer, withPresentationTime: time) { lastTime = time }
    }

    func finish(_ completion: @escaping (Result<Clip, Error>) -> Void) {
        guard firstTime != nil, writer.status == .writing else {
            writer.cancelWriting()
            completion(.failure(SCOOError.message("너무 짧아서 동영상을 만들지 못했어요.")))
            return
        }
        let seconds = self.seconds
        let poster = self.poster.flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.9) }
        input.markAsFinished()
        writer.finishWriting { [writer, url] in
            if writer.status == .completed, let poster {
                completion(.success(Clip(url: url, poster: poster, seconds: seconds)))
            } else {
                try? FileManager.default.removeItem(at: url)
                completion(.failure(writer.error ?? SCOOError.message("동영상을 저장하지 못했어요.")))
            }
        }
    }

    /// Moves the frame to the origin and scales it to the clip size.
    private func fit(_ image: CIImage) -> CIImage {
        let moved = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        guard moved.extent.width > 0, moved.extent.height > 0 else { return moved }
        return moved.transformed(by: CGAffineTransform(scaleX: size.width / moved.extent.width, y: size.height / moved.extent.height))
    }
}
