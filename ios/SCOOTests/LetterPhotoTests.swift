import XCTest
import UIKit
@testable import SCOO

final class LetterPhotoTests: XCTestCase {
    func testPhotosAreShrunkAndReencoded() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let data = try XCTUnwrap(LetterPhoto.prepare(try XCTUnwrap(big.pngData())))
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(image.size.width * image.scale, image.size.height * image.scale), LetterPhoto.maxSide)
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8], "JPEG")
        XCTAssertNil(LetterPhoto.prepare(Data("not an image".utf8)))
    }

    func testOlderServerRowsStillDecode() throws {
        let row = #"{"friend_id":"aaaaaaaa-0000-4000-8000-000000000001","nickname":"졸린 모리","friend_code":"ABC234","hero":null,"status":"friend","last_body":null,"last_sticker":null,"last_at":null,"unread":0}"#
        let friend = try JSONDecoder().decode(FriendRow.self, from: Data(row.utf8))
        XCTAssertNil(friend.last_photo)
        let photo = #"{"friend_id":"aaaaaaaa-0000-4000-8000-000000000001","nickname":null,"friend_code":"ABC234","hero":null,"status":"friend","last_body":null,"last_sticker":null,"last_at":null,"unread":1,"last_photo":true}"#
        XCTAssertEqual(try JSONDecoder().decode(FriendRow.self, from: Data(photo.utf8)).preview, "사진")
    }
}
