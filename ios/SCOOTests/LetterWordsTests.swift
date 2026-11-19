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
        XCTAssertEqual(text, BottleRules.realArrival, "no word yet: only that the baby arrived")
    }

    func testSimulatedSeaIsStable() {
        let bottle = sent()
        let later = BottleRules.letterDate(bottle, index: 5, fast: false)
        let once = BottleRules.letters(for: [bottle], now: later, fast: false).map(\.text)
        XCTAssertEqual(once, BottleRules.letters(for: [bottle], now: later, fast: false).map(\.text))
        XCTAssertEqual(once.count, BottleRules.maxLetters)
    }

    func testCopulaAndQuoteFollowTheLastSyllable() {
        XCTAssertEqual(LetterWords.withCopula("충남 부여군"), "충남 부여군이야")
        XCTAssertEqual(LetterWords.withCopula("세종"), "세종이야")
        XCTAssertEqual(LetterWords.withCopula("서울 마포구"), "서울 마포구야")
        XCTAssertEqual(LetterWords.withQuote("멜로"), "멜로라는")
        XCTAssertEqual(LetterWords.withQuote("시나몬"), "시나몬이라는")
    }

    func testRealPeopleNeverGetMadeUpPlacesOrExtraLetters() {
        let bottle = sent()
        let later = BottleRules.letterDate(bottle, index: 5, fast: false)
        let second = BottleRules.letterDate(bottle, index: 1, fast: false)
        let moments = [BottleMoment(bottleID: bottle.id, subject: "flower", date: second.addingTimeInterval(-60))]
        let letters = BottleRules.letters(for: [bottle], now: later, fast: false, moments: moments)
        XCTAssertEqual(letters.count, 2, "도착 편지 하나와 꽃 사진이 있던 날의 편지 하나만")
        XCTAssertEqual(letters.last?.text, BottleRules.realArrival)
        XCTAssertTrue(letters[0].text.contains("꽃"))
        XCTAssertTrue(BottleRules.letters(for: [bottle], now: later, fast: false, moments: []).count == 1)
    }

    func testSimulatedLettersSpeakProperly() {
        for _ in 0..<50 {
            let text = BottleRules.letterText(sent(), index: 0)
            let place = text.replacingOccurrences(of: "잘 도착했어! 여기는 ", with: "").components(separatedBy: ".")[0]
            let stem = String(place.dropLast(place.hasSuffix("이야") ? 2 : 1))
            XCTAssertEqual(LetterWords.withCopula(stem), place)
        }
    }
}
