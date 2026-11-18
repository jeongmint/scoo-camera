import XCTest
@testable import SCOO

final class ExplorationTests: XCTestCase {
    private func region(_ id: String) -> Region { Regions.find(id)! }

    func testFirstPhotoInAPlaceStampsItOnce() {
        var state = Exploration()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(state.visit(region("서울 송파구"), now: now))
        XCTAssertFalse(state.visit(region("서울 송파구"), now: now), "두 번째 방문은 도장 없음")
        XCTAssertTrue(state.visit(region("경북 청송군"), now: now))
        XCTAssertEqual(state.visited.count, 2)
        XCTAssertEqual(state.visits(in: .seoul), 1)
        XCTAssertTrue(state.met.isEmpty, "탐험으로는 친구가 생기지 않아요")
    }

    func testOldSeoulRecordsMoveToRegionIDs() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "exploration-old-\(UUID().uuidString)"))
        let old = #"{"visited":{"마포구":0},"met":[{"species":"deogi","district":"마포구","date":0}]}"#
        defaults.set(Data(old.utf8), forKey: Exploration.key)
        let state = Exploration.load(from: defaults)
        XCTAssertNotNil(state.visited["서울 마포구"])
        XCTAssertEqual(state.met.first?.district, "서울 마포구")
        XCTAssertEqual(state.met.first?.place, "서울 마포구")
    }

    func testStateRoundTripsThroughDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "exploration-test-\(UUID().uuidString)"))
        XCTAssertEqual(Exploration.load(from: defaults), Exploration())
        XCTAssertTrue(Exploration.record(region("전남 보성군"), defaults: defaults))
        XCTAssertFalse(Exploration.record(region("전남 보성군"), defaults: defaults))
        XCTAssertEqual(Exploration.load(from: defaults).visited.count, 1)
    }
}
