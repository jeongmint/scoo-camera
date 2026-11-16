import XCTest
import UIKit
@testable import SCOO

/// Small seeded generator so the random draw can be checked deterministically.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

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

    func testRandomDrawNeverHandsOutTheEventSnowman() {
        XCTAssertEqual(Set(Companion.regulars), [.gwiyo, .kuru, .mori, .nyamo])
        XCTAssertTrue(Companion.happy.isEvent)
        var generator = SeededGenerator(state: 42)
        let draws = (0..<400).map { _ in Companion.assign(using: &generator) }
        XCTAssertFalse(draws.contains(.happy))
        XCTAssertEqual(Set(draws), Set(Companion.regulars), "400번 뽑으면 네 명 모두 나와야 해요")
    }

    func testEachUserOwnsTheirDrawPlusTheOpenEventFriend() {
        for friend in Companion.regulars {
            let owned = Companion.owned(assigned: friend)
            XCTAssertEqual(owned.first, friend)
            XCTAssertEqual(owned.count, 1 + Companion.openEvents.count)
            XCTAssertTrue(owned.contains(.happy), "테스트 버전에서는 눈사람도 함께 받아요")
            XCTAssertEqual(Set(owned).count, owned.count)
        }
    }

    func testSpotIsASquareAroundTheFloatingCenter() {
        let spot = CompanionSpot(center: CGPoint(x: 0.5, y: 0.74), width: 0.25)
        let frame = spot.frame(in: CGSize(width: 400, height: 800))
        XCTAssertEqual(frame.width, 100, accuracy: 0.001)
        XCTAssertEqual(frame.height, 100, accuracy: 0.001)
        XCTAssertEqual(frame.midX, 200, accuracy: 0.001)
        XCTAssertEqual(frame.midY, 592, accuracy: 0.001)
    }

    func testSameSpotInPhotoAndViewfinder() {
        // Mori is 90pt wide at (300, 620) on a 390×844 screen; the photo is cropped to the same aspect.
        let spot = CompanionSpot(center: CGPoint(x: 300.0 / 390, y: 620.0 / 844), width: 90.0 / 390)
        let screen = spot.frame(in: CGSize(width: 390, height: 844))
        let photo = spot.frame(in: CGSize(width: 1170, height: 2532))   // same aspect, 3× pixels
        XCTAssertEqual(screen.width, 90, accuracy: 0.001)
        XCTAssertEqual(photo.width, 270, accuracy: 0.001)
        XCTAssertEqual(photo.minX / 1170, screen.minX / 390, accuracy: 0.0001)
        XCTAssertEqual(photo.minY / 2532, screen.minY / 844, accuracy: 0.0001)
    }

    func testImportedPhotoKeepsTheFriendSquare() {
        let spot = CompanionSpot(center: CGPoint(x: 0.5, y: 0.74), width: CompanionSpot.defaultWidth)
        let landscape = spot.frame(in: CGSize(width: 2400, height: 1600))
        XCTAssertEqual(landscape.width, landscape.height, accuracy: 0.001)
    }
}
