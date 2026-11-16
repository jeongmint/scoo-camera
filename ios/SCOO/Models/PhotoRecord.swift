import Foundation
import ImageIO

/// Where a photo was taken, for the map guestbook. Stored only on the device.
struct PhotoLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    /// GPS from an imported photo's metadata, if it has any.
    static func fromImageData(_ data: Data) -> PhotoLocation? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double else { return nil }
        let south = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S"
        let west = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W"
        return PhotoLocation(latitude: south ? -latitude : latitude, longitude: west ? -longitude : longitude)
    }
}

struct PhotoRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let filename: String
    let filter: String
    let isFood: Bool
    let mode: CaptureMode
    let experience: Int
    let bonus: Int
    let classificationNote: String
    /// Added later; older records decode with nil.
    var location: PhotoLocation? = nil
}

struct GardenSnapshot: Codable {
    var name = "모리"
    var experience = 0
    var moments = 0
    var birthday = Date()
    var photos: [PhotoRecord] = []
}

struct ProcessedPhoto {
    let jpeg: Data
    let isFood: Bool
    let bonus: Int
    let classificationNote: String
    /// Apple Vision scene labels seen in the photo (for 오늘의 미션).
    var labels: [String] = []
}

enum SCOOError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
