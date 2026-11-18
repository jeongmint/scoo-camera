import XCTest
@testable import SCOO

final class LetterWordsTests: XCTestCase {
    private let arrived = Date(timeIntervalSince1970: 1_800_000_000)

    private func sent() -> Bottle {
        Bottle(id: UUID(), direction: .outgoing, parentA: "tori", parentB: "sia", origin: "성동구",
               sentAt: arrived.addingTimeInterval(-86_400), arrivesAt: arrived, wantsNews: true)
    }

    func testPhotoLabelsBecomeFixedSubjects() {
        XCTAssertEqual(LetterWords.subjects(labels: ["cat", "blue_sky"], isFood: false).sorted(), ["cat", "sky"])
        XCTAssertEqual(LetterWords.subjects(labels: ["ramen"], isFood: true), ["food"])
        XCTAssertTrue(LetterWords.subjects(labels: ["person", "car"], isFood: false).isEmpty)
        // every subject is one the server accepts
        XCTAssertEqual(Set(LetterWords.words.keys), Set(DailyMission.all.map(\.id) + ["food"]))
    }

    func testObjectParticleFollowsTheLastSyllable() {
        XCTAssertEqual(LetterWords.withObjectParticle("고양이"), "고양이를")
        XCTAssertEqual(LetterWords.withObjectParticle("하늘"), "하늘을")
        XCTAssertEqual(LetterWords.withObjectParticle("꽃"), "꽃을")
        XCTAssertEqual(LetterWords.withObjectParticle("맛있는 음식"), "맛있는 음식을")
    }

    func testLetterTalksAboutWhatWasSharedBeforeIt() {
        let bottle = sent()
        let first = BottleRules.letterDate(bottle, index: 0, fast: false)
        let moments = [BottleMoment(bottleID: bottle.id, subject: "cat", date: arrived.addingTimeInterval(3600))]
        let letters = BottleRules.letters(for: [bottle], now: first, fast: false, moments: moments)
        XCTAssertEqual(letters.count, 1)
        XCTAssertEqual(letters[0].text, "오늘 새 가족이랑 고양이를 봤어! 너도 좋아했을 거야.")
    }

    func testOtherBottlesAndLaterWordsDoNotLeakIn() {
        let bottle = sent()
        let first = BottleRules.letterDate(bottle, index: 0, fast: false)
        let moments = [
            BottleMoment(bottleID: UUID(), subject: "cat", date: arrived.addingTimeInterval(3600)),
            BottleMoment(bottleID: bottle.id, subject: "dog", date: first.addingTimeInterval(60)),
        ]
        let text = BottleRules.letters(for: [bottle], now: first, fast: false, moments: moments)[0].text
        XCTAssertEqual(text, BottleRules.letterText(bottle, index: 0), "no word yet: the usual line")
    }

    func testSimulatedSeaIsStable() {
        let bottle = sent()
        let later = BottleRules.letterDate(bottle, index: 5, fast: false)
        let once = BottleRules.letters(for: [bottle], now: later, fast: false).map(\.text)
        XCTAssertEqual(once, BottleRules.letters(for: [bottle], now: later, fast: false).map(\.text))
        XCTAssertEqual(once.count, BottleRules.maxLetters)
    }
}
