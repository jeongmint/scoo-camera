import XCTest
import UIKit
@testable import SCOO

final class CompanionTests: XCTestCase {
    func testEveryFriendHasAnImageInTheApp() {
        for friend in Companion.allCases {
            XCTAssertNotNil(UIImage(named: friend.assetName), "\(friend.title) 이미지가 없어요")
        }
    }

    func testTitlesAndAssetNamesAreUnique() {
        XCTAssertEqual(Set(Companion.allCases.map(\.title)).count, Companion.allCases.count)
        XCTAssertEqual(Set(Companion.allCases.map(\.assetName)).count, Companion.allCases.count)
    }

    func testEmptyOrUnknownPreferenceMeansShootingAlone() {
        XCTAssertNil(Companion(rawValue: ""))
        XCTAssertNil(Companion(rawValue: "unknown"))
        XCTAssertEqual(Companion(rawValue: "nyamo"), .nyamo)
    }

    func testFriendStaysInsideEveryFrameAndAboveTheControls() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844), CGSize(width: 1000, height: 3000)] {
            let frame = Companion.frame(in: size)
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertLessThanOrEqual(frame.maxX, size.width)
            XCTAssertGreaterThanOrEqual(frame.minY, 0)
            XCTAssertEqual(frame.width, frame.height, accuracy: 0.001)
            XCTAssertEqual(frame.width / size.width, Companion.widthRatio, accuracy: 0.001)
        }
        // Keep clear of the bottom controls on a standard phone (same margin Mori uses).
        XCTAssertLessThanOrEqual(Companion.frame(in: CGSize(width: 390, height: 844)).maxY, 844 - 124)
    }

    func testSameSpotInPhotoAndViewfinder() {
        let screen = Companion.frame(in: CGSize(width: 390, height: 844))
        let photo = Companion.frame(in: CGSize(width: 1170, height: 2532))   // same aspect, 3× pixels
        XCTAssertEqual(photo.minX / 1170, screen.minX / 390, accuracy: 0.0001)
        XCTAssertEqual(photo.minY / 2532, screen.minY / 844, accuracy: 0.0001)
    }
}
