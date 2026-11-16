import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import SCOO

final class PlaceTests: XCTestCase {
    func testOldRecordsWithoutLocationStillLoad() throws {
        let old = """
        {"id":"7E0E9CE0-0000-4000-8000-000000000001","date":0,"filename":"a.jpg","filter":"Eternal","isFood":false,
         "mode":"auto","experience":12,"bonus":0,"classificationNote":"일상"}
        """
        let record = try JSONDecoder().decode(PhotoRecord.self, from: Data(old.utf8))
        XCTAssertNil(record.location)
        XCTAssertFalse(record.isVideo, "예전 기록은 사진이에요")
    }

    func testLocationRoundTrips() throws {
        let record = PhotoRecord(id: UUID(), date: Date(timeIntervalSince1970: 0), filename: "a.jpg", filter: "Eternal", isFood: true,
                                 mode: .food, experience: 20, bonus: 3, classificationNote: "음식",
                                 location: PhotoLocation(latitude: 37.5446, longitude: 127.0559))
        let back = try JSONDecoder().decode(PhotoRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(back.location, record.location)
    }

    /// A tiny JPEG carrying GPS for a spot south and west of the equator / meridian.
    private func jpeg(latitude: Double, latitudeRef: String, longitude: Double, longitudeRef: String) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: latitude, kCGImagePropertyGPSLatitudeRef: latitudeRef,
                                    kCGImagePropertyGPSLongitude: longitude, kCGImagePropertyGPSLongitudeRef: longitudeRef]
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func testImportedPhotoGPSIsRead() throws {
        let seoul = try XCTUnwrap(PhotoLocation.fromImageData(jpeg(latitude: 37.5446, latitudeRef: "N", longitude: 127.0559, longitudeRef: "E")))
        XCTAssertEqual(seoul.latitude, 37.5446, accuracy: 0.0001)
        XCTAssertEqual(seoul.longitude, 127.0559, accuracy: 0.0001)
        let south = try XCTUnwrap(PhotoLocation.fromImageData(jpeg(latitude: 33.86, latitudeRef: "S", longitude: 70.5, longitudeRef: "W")))
        XCTAssertEqual(south.latitude, -33.86, accuracy: 0.0001)
        XCTAssertEqual(south.longitude, -70.5, accuracy: 0.0001)
    }

    func testPhotoWithoutGPSHasNoPlace() {
        XCTAssertNil(PhotoLocation.fromImageData(Data("not an image".utf8)))
    }
}
