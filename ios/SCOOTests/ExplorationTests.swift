import XCTest
@testable import SCOO

final class ExplorationTests: XCTestCase {
    private func region(_ id: String) -> Region { Regions.find(id)! }

    func testFirstPhotoInAPlaceMeetsItsFriendOnce() {
        var state = Exploration()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(state.visit(region("서울 송파구"), owned: [], now: now), .met(Species.find("baseball")!))
        XCTAssertEqual(state.visit(region("서울 송파구"), owned: [], now: now), .again, "두 번째 방문은 만남 없음")
        XCTAssertEqual(state.collected, ["baseball"])
        XCTAssertNotNil(state.visited["서울 송파구"])
    }

    func testAFriendMetElsewhereOnlyStampsTheNewPlace() {
        var state = Exploration()
        _ = state.visit(region("경북 청송군"), owned: [], now: Date())          // 디아(사과)
        XCTAssertEqual(state.visit(region("충북 충주시"), owned: [], now: Date()), .stamped(Species.find("dia")))
        XCTAssertEqual(state.visited.count, 2)
        XCTAssertEqual(state.met.count, 1)
    }

    func testOwnFriendIsNotMetAgainAndCollectedJoinBreeding() {
        var state = Exploration()
        // 성북구's friend is 토리; already owned → just a stamp
        XCTAssertEqual(state.visit(region("서울 성북구"), owned: ["tori"], now: Date()), .stamped(Species.find("tori")))
        let owned = Species.owned(assigned: .kuru, unlockAll: false, collected: ["tori", "kuru"])
        XCTAssertEqual(owned.map(\.id), ["kuru", "happy", "tori"], "받은 친구, 이벤트, 만난 친구 순서이고 겹치지 않아요")
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
        XCTAssertEqual(Exploration.record(region("전남 보성군"), owned: [], defaults: defaults), .met(Species.find("popo")!))
        XCTAssertEqual(Exploration.load(from: defaults).collected, ["popo"])
        XCTAssertEqual(Exploration.record(region("전남 보성군"), owned: [], defaults: defaults), .again)
    }
}
