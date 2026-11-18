import XCTest
@testable import SCOO

@MainActor
final class FriendStoreTests: XCTestCase {
    private func defaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "friends-\(UUID().uuidString)"))
    }

    func testOldUsersKeepTheirDrawTheSnowmanAndExploredFriends() throws {
        let old = try defaults()
        old.set("kuru", forKey: "assignedCompanion")
        let exploration = #"{"visited":{"마포구":0},"met":[{"species":"deogi","district":"마포구","date":0}]}"#
        old.set(Data(exploration.utf8), forKey: Exploration.key)
        let store = FriendStore(defaults: old)
        XCTAssertEqual(store.friends.map(\.species), ["kuru", "happy", "deogi"])
        XCTAssertEqual(store.starter?.species, "kuru")
        XCTAssertEqual(store.friends.last?.origin, "서울 마포구")
        // saved: a second store reads the same list
        XCTAssertEqual(FriendStore(defaults: old).friends, store.friends)
    }

    func testNewUserHasNothingUntilTheFirstDraw() throws {
        let store = FriendStore(defaults: try defaults())
        XCTAssertTrue(store.friends.isEmpty)
        XCTAssertFalse(store.hasStarter)
        store.setStarter(Species.find("otter")!, origin: "전남 구례군")
        store.setStarter(Species.find("dia")!, origin: "경북 청송군")
        XCTAssertEqual(store.friends.map(\.species), ["dia"], "다시 받으면 첫 친구만 바뀌어요")
        XCTAssertEqual(store.seen, ["otter", "dia"], "도감은 떠난 친구도 기억해요")
    }

    func testTheLastOneNeverLeavesAndEventFriendsStay() {
        XCTAssertFalse(BottleStore.canPart(friends: 1, babies: 0))
        XCTAssertTrue(BottleStore.canPart(friends: 1, babies: 1))
        XCTAssertTrue(BottleStore.canPart(friends: 2, babies: 0))
        XCTAssertFalse(OwnedFriend(id: UUID(), species: "happy", how: .event, since: Date()).canTravel)
        XCTAssertTrue(OwnedFriend(id: UUID(), species: "mori", how: .starter, since: Date()).canTravel)
    }

    func testTheSeaPrefersTheLocalFiveTheUserDoesNotHave() throws {
        let store = FriendStore(defaults: try defaults())
        let region = Regions.find("서울 마포구")!
        for id in region.candidates.dropLast() { store.add(Species.find(id)!, how: .adopted, origin: nil) }
        var generator = SystemRandomNumberGenerator()
        XCTAssertEqual(store.seaFriend(near: region, using: &generator).id, region.candidates.last)
    }

    func testSendingAFriendAndTheNextDayAnswer() async throws {
        let store = FriendStore(defaults: try defaults())
        store.setStarter(Species.find("mori")!, origin: "서울 마포구")
        store.add(Species.find("kuru")!, how: .adopted, origin: nil)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bottles = BottleStore(directory: directory)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let kuru = store.friends[1]
        try await bottles.send(kuru, wantsNews: true, from: "서울 마포구", friends: store, babies: 0, fast: false, now: start)
        XCTAssertEqual(store.friends.map(\.species), ["mori"])
        let sent = try XCTUnwrap(bottles.bottles.first { $0.direction == .outgoing })
        XCTAssertTrue(sent.isCharacter)
        XCTAssertEqual(sent.title, "쿠르")

        // the last one stays home
        do {
            try await bottles.send(store.friends[0], wantsNews: false, from: nil, friends: store, babies: 0, fast: false,
                                   now: start.addingTimeInterval(2 * 86_400))
            XCTFail("마지막 한 마리는 못 보내요")
        } catch { }

        let nextDay = start.addingTimeInterval(86_401)
        if LocalBottleBackend.someoneCame(sent.id) {
            XCTAssertTrue(bottles.bottles.contains { $0.direction == .incoming }, "짝이 있으면 다음 날 입양")
            let came = await bottles.settleWaiting(home: nil, friends: store, fast: false, now: nextDay)
            XCTAssertTrue(came.isEmpty)
        } else {
            let early = await bottles.settleWaiting(home: nil, friends: store, fast: false, now: start.addingTimeInterval(3_600))
            XCTAssertTrue(early.isEmpty, "하루가 지나야 와요")
            let came = await bottles.settleWaiting(home: Regions.find("서울 마포구"), friends: store, fast: false, now: nextDay)
            XCTAssertEqual(came.count, 1, "짝이 없으면 바다에서 새 친구")
            XCTAssertEqual(store.friends.last?.how, .sea)
            let again = await bottles.settleWaiting(home: nil, friends: store, fast: false, now: nextDay.addingTimeInterval(60))
            XCTAssertTrue(again.isEmpty, "한 번만")
        }
    }

    func testTheSeaAnswersWithTheFriendsOfWhereTheBottleLeft() async throws {
        let store = FriendStore(defaults: try defaults())
        store.setStarter(Species.find("mori")!, origin: "서울 마포구")
        store.add(Species.find("kuru")!, how: .adopted, origin: nil)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bottles = BottleStore(directory: directory, luck: { _ in false })   // nobody at sea
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        try await bottles.send(store.friends[1], wantsNews: false, from: "전북 무주군", friends: store, babies: 0, fast: false, now: start)
        XCTAssertEqual(bottles.bottles.first?.origin, "전북 무주군")
        let came = await bottles.settleWaiting(home: Regions.find("서울 마포구"), friends: store, fast: false,
                                               now: start.addingTimeInterval(86_401))
        XCTAssertEqual(came.count, 1)
        XCTAssertTrue(Regions.find("전북 무주군")!.candidates.contains(came[0].id), "무주에서 띄우면 무주의 다섯 친구 중 하나")
        XCTAssertEqual(store.friends.last?.origin, "전북 무주군")
    }
}
