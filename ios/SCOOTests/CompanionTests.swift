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
