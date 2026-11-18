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
    func testAnyCharacterCanFloatAndHasAPicture() {
        for species in Species.all {
            XCTAssertNotNil(UIImage(named: species.assetName), "\(species.name) 이미지가 없어요")
        }
        XCTAssertEqual(Set(Species.all.map(\.assetName)).count, Species.all.count)
        XCTAssertNil(Species.find(""), "빈 선택은 혼자 찍기")
    }

    func testStarterComesFromThePlacesFiveAndNeverTheSnowman() {
        var generator = SeededGenerator(state: 42)
        let region = Regions.find("서울 마포구")!
        let draws = (0..<400).map { _ in region.drawStarter(using: &generator).id }
        XCTAssertEqual(Set(draws), Set(region.candidates), "400번 뽑으면 다섯 친구 모두 나와요")
        XCTAssertFalse(draws.contains("happy"))
        let anywhere = (0..<400).map { _ in Regions.randomStarter(using: &generator) }
        XCTAssertFalse(anywhere.contains { $0.isEvent })
        XCTAssertEqual(Species.regulars.count, 38)
    }

    func testOneSeasonalFriendPerSeason() {
        func day(_ month: Int) -> Date { DateComponents(calendar: .current, year: 2026, month: month, day: 15).date! }
        XCTAssertEqual(Species.openEvents(at: day(1)), ["happy"])
        XCTAssertEqual(Species.openEvents(at: day(4)), ["bomi"])
        XCTAssertEqual(Species.openEvents(at: day(7)), ["soru"])
        XCTAssertEqual(Species.openEvents(at: day(11)), ["doto"])
        XCTAssertEqual(Species.openEvents(at: day(12)), ["happy"])
        XCTAssertEqual(Season.allCases.map { Season.of(day([4, 7, 10, 1][Season.allCases.firstIndex(of: $0)!])) }, Season.allCases)
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
