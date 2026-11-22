import XCTest
@testable import SCOO

@MainActor
final class FriendGrowthTests: XCTestCase {
    private func store() -> FriendStore {
        let name = "FriendGrowthTests-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return FriendStore(defaults: defaults)
    }

    func testStagesFollowTheFriendsOwnLevel() {
        XCTAssertEqual(FriendGrowth.stage(level: 1), .baby)
        XCTAssertEqual(FriendGrowth.stage(level: 2), .baby)
        XCTAssertEqual(FriendGrowth.stage(level: 3), .growing)
        XCTAssertEqual(FriendGrowth.stage(level: 5), .bloom)
        XCTAssertEqual(FriendGrowth.toNextStage(xp: 0), 200, "레벨 3은 200 EXP")
        XCTAssertEqual(FriendGrowth.toNextStage(xp: 250), 150, "레벨 5는 400 EXP")
        XCTAssertNil(FriendGrowth.toNextStage(xp: 400))
    }

    func testOnlyTheFloatingFriendGrows() {
        let friends = store()
        friends.add(Species.find("mello")!, how: .starter, origin: nil)
        friends.add(Species.find("doto")!, how: .event, origin: nil)
        friends.gain(120, species: "mello")
        friends.gain(30, species: "mello")
        XCTAssertEqual(friends.friend(for: "mello")?.xp, 150)
        XCTAssertEqual(friends.friend(for: "mello")?.photos, 2)
        XCTAssertEqual(friends.friend(for: "mello")?.growth.level, 2)
        XCTAssertEqual(friends.friend(for: "doto")?.xp, 0, "다른 친구는 그대로")
        XCTAssertNil(friends.gain(50, species: "luna"), "없는 친구는 자라지 않아요")
    }

    func testOnlyBloomedFriendsCanBreed() {
        let friends = store()
        friends.add(Species.find("mello")!, how: .starter, origin: nil)
        friends.add(Species.find("luna")!, how: .sea, origin: nil)
        XCTAssertTrue(friends.bloomed.isEmpty)
        friends.gain(400, species: "luna")
        XCTAssertEqual(friends.bloomed.map(\.id), ["luna"])
    }

    func testOlderRecordsWithoutExperienceStartAtLevelOne() throws {
        let old = #"{"id":"6A2C1E0F-0000-4000-8000-000000000001","species":"mori","how":"starter","since":0}"#
        let friend = try JSONDecoder().decode(OwnedFriend.self, from: Data(old.utf8))
        XCTAssertEqual(friend.xp, 0)
        XCTAssertEqual(friend.growth.level, 1)
        XCTAssertEqual(friend.stage, .baby)
    }

    func testSubjectParticle() {
        XCTAssertEqual(LetterWords.withSubject("귤"), "귤이")
        XCTAssertEqual(LetterWords.withSubject("도도"), "도도가")
    }
}
