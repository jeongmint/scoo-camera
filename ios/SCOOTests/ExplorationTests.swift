import XCTest
@testable import SCOO

final class ExplorationTests: XCTestCase {
    private struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state &+= 0x9E3779B97F4A7C15; var z = state; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; return z ^ (z >> 31) }
    }

    func testTwentyDistrictsEachHaveTheirOwnLocalFriend() {
        let specials = SeoulDistrict.allCases.compactMap(\.special)
        XCTAssertEqual(specials.count, 20)
        XCTAssertEqual(Set(specials.map(\.id)).count, 20, "한 친구는 한 구에만 살아요")
        let basics: Set<String> = ["gwiyo", "kuru", "mori", "nyamo", "happy"]
        XCTAssertTrue(specials.allSatisfy { !basics.contains($0.id) }, "동네 친구는 새 20종이에요")
    }

    func testFirstPhotoInADistrictMeetsItsFriendOnce() {
        var state = Exploration()
        var generator = Seeded(state: 1)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(state.visit(.songpa, owned: [], now: now, using: &generator)?.id, "baseball")
        XCTAssertNil(state.visit(.songpa, owned: [], now: now, using: &generator), "두 번째 방문은 만남 없음")
        XCTAssertEqual(state.collected, ["baseball"])
        XCTAssertNotNil(state.visited["송파구"])
    }

    func testDistrictWithoutLocalFriendBringsSomeoneNew() {
        var state = Exploration()
        var generator = Seeded(state: 2)
        let owned: Set<String> = ["mori", "happy"]
        let met = state.visit(.gangnam, owned: owned, now: Date(), using: &generator)
        XCTAssertNotNil(met)
        XCTAssertFalse(owned.contains(met?.id ?? "mori"))
        XCTAssertFalse(met?.isEvent ?? true)
    }

    func testOwnedFriendsAreNotMetAgainAndCollectedJoinBreeding() {
        var state = Exploration()
        var generator = Seeded(state: 3)
        // 성북구's friend is 토리; if 토리 is already owned, someone else turns up
        let met = state.visit(.seongbuk, owned: ["tori"], now: Date(), using: &generator)
        XCTAssertNotEqual(met?.id, "tori")
        let owned = Species.owned(assigned: .kuru, unlockAll: false, collected: ["tori", "kuru"])
        XCTAssertEqual(owned.map(\.id), ["kuru", "happy", "tori"], "받은 친구, 이벤트, 만난 친구 순서이고 겹치지 않아요")
    }

    func testStateRoundTripsThroughDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "exploration-test-\(UUID().uuidString)"))
        XCTAssertEqual(Exploration.load(from: defaults), Exploration())
        let met = Exploration.record(.jongno, owned: [], defaults: defaults)
        XCTAssertEqual(met?.id, "popo")
        XCTAssertEqual(Exploration.load(from: defaults).collected, ["popo"])
        XCTAssertNil(Exploration.record(.jongno, owned: [], defaults: defaults))
    }
}
