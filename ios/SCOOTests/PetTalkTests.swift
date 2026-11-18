import XCTest
@testable import SCOO

final class PetTalkTests: XCTestCase {
    func testBoredGetsCheeredUp() {
        let reply = LocalReplies.reply(to: "오늘 지겨워!", roll: 0)
        XCTAssertEqual(reply.text, "왜 지겨워… 힘내! 나랑 바깥 구경하러 갈래?")
        XCTAssertEqual(reply.mood, .surprised)
    }

    func testKeywordsIgnoreSpacing() {
        XCTAssertEqual(LocalReplies.reply(to: "배 고 파", roll: 0.99).mood, .yum)
        XCTAssertEqual(LocalReplies.reply(to: "너무 피곤해", roll: 0.5).mood, .normal)
    }

    func testDangerComesBeforeEverythingElse() {
        // "힘들" also matches the tired rule; the safety line must win.
        let reply = LocalReplies.reply(to: "너무 힘들어서 죽고 싶어", roll: 0.7)
        XCTAssertTrue(reply.text.contains("109"))
    }

    func testUnknownWordsStillGetAnAnswer() {
        for roll in [0.0, 0.5, 0.999] {
            XCTAssertFalse(LocalReplies.reply(to: "블루베리", roll: roll).text.isEmpty)
        }
    }

    func testServerMoodNames() {
        XCTAssertEqual(TalkReply.mood(named: "yum"), .yum)
        XCTAssertEqual(TalkReply.mood(named: "awe"), .awe)
        XCTAssertEqual(TalkReply.mood(named: nil), .smile)
        XCTAssertEqual(TalkReply.mood(named: "angry"), .smile)
    }

    func testEachFriendHasItsOwnNameAndColor() {
        let mori = TalkPet.of(nil, moriName: "포근한 모리", personality: "먹보")
        XCTAssertEqual(mori.name, "포근한 모리")
        XCTAssertEqual(mori.personality, "먹보")
        let nyamo = TalkPet.of(Species.find("nyamo"), moriName: "포근한 모리", personality: "먹보")
        XCTAssertEqual(nyamo.name, "냐모")
        XCTAssertNotEqual(nyamo.tint.red, mori.tint.red)
        XCTAssertEqual(TalkPet.of(Species.find("mori"), moriName: "콩", personality: "x").name, "모리")
        for species in Species.all {
            XCTAssertEqual(TalkPet.of(species, moriName: "콩", personality: "x").name, species.id == "mori" ? "모리" : species.name)
        }
    }
}
