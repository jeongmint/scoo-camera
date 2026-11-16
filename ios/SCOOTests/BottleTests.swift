import XCTest
@testable import SCOO

final class BottleTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func outgoing(at date: Date, news: Bool = true, fast: Bool = false) -> Bottle {
        Bottle(id: UUID(), direction: .outgoing, parentA: "tori", parentB: "sia", origin: "성동구",
               sentAt: date, arrivesAt: date.addingTimeInterval(BottleRules.travelTime(fast: fast)), wantsNews: news)
    }

    func testOneBottleADayUnlessFast() {
        let sent = [outgoing(at: start)]
        XCTAssertTrue(BottleRules.canSend([], now: start, fast: false))
        XCTAssertFalse(BottleRules.canSend(sent, now: start.addingTimeInterval(60), fast: false))
        XCTAssertTrue(BottleRules.canSend(sent, now: start.addingTimeInterval(60), fast: true))
        XCTAssertTrue(BottleRules.canSend(sent, now: start.addingTimeInterval(2 * 24 * 60 * 60), fast: false))
    }

    func testLettersArriveOverTimeAndStop() {
        let bottle = outgoing(at: start)
        XCTAssertTrue(BottleRules.letters(for: [bottle], now: bottle.arrivesAt, fast: false).isEmpty, "도착하자마자는 아직 편지가 없어요")
        let later = bottle.arrivesAt.addingTimeInterval(7 * 60 * 60)
        XCTAssertEqual(BottleRules.letters(for: [bottle], now: later, fast: false).count, 1)
        let muchLater = bottle.arrivesAt.addingTimeInterval(100 * 24 * 60 * 60)
        XCTAssertEqual(BottleRules.letters(for: [bottle], now: muchLater, fast: false).count, BottleRules.maxLetters)
        XCTAssertTrue(BottleRules.letters(for: [outgoing(at: start, news: false)], now: muchLater, fast: false).isEmpty)
    }

    func testTheSameBottleTellsTheSameStory() {
        let bottle = outgoing(at: start)
        XCTAssertEqual(BottleRules.letterText(bottle, index: 1), BottleRules.letterText(bottle, index: 1))
        XCTAssertTrue(BottleRules.letterText(bottle, index: 3).contains("성동구"))
    }

    func testTheSeaSendsABabyFromSeoulThatArrivesLater() {
        var generator = StableGenerator(seed: 11)
        let sent = outgoing(at: start)
        for _ in 0..<200 {
            let back = LocalOcean.make(after: sent, fast: false, using: &generator)
            XCTAssertEqual(back.direction, .incoming)
            XCTAssertNotEqual(back.parentA, back.parentB)
            XCTAssertFalse(Species.find(back.parentA)?.isEvent ?? true)
            XCTAssertFalse(Species.find(back.parentB)?.isEvent ?? true)
            XCTAssertNotNil(SeoulDistrict(rawValue: back.origin))
            XCTAssertGreaterThan(back.arrivesAt, sent.arrivesAt)
        }
    }

    func testOldBreedRecordsStillLoad() throws {
        let old = """
        [{"id":"7E0E9CE0-0000-4000-8000-000000000002","parentA":"tori","parentB":"sia","born":0,"bornAtMoment":3}]
        """
        let breeds = try JSONDecoder().decode([Breed].self, from: Data(old.utf8))
        XCTAssertNil(breeds.first?.origin)
    }

    @MainActor
    func testSendingAndOpeningMovesBabies() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let breeds = BreedStore(directory: folder)
        let bottles = BottleStore(directory: folder)
        let baby = try breeds.hatch(a: "tori", b: "sia", moments: 0, now: start)

        try bottles.send(baby, wantsNews: true, from: "마포구", breeds: breeds, fast: true, now: start)
        XCTAssertTrue(breeds.breeds.isEmpty, "띄운 아이는 목록에서 떠나요")
        XCTAssertEqual(bottles.bottles.count, 2)
        let incoming = try XCTUnwrap(bottles.bottles.first { $0.direction == .incoming })
        XCTAssertThrowsError(try bottles.open(incoming, breeds: breeds, moments: 5, now: start), "도착 전엔 열 수 없어요")

        let later = incoming.arrivesAt.addingTimeInterval(1)
        let adopted = try bottles.open(incoming, breeds: breeds, moments: 5, now: later)
        XCTAssertEqual(adopted.origin, incoming.origin)
        XCTAssertEqual(breeds.breeds.map(\.id), [adopted.id])
        XCTAssertTrue(bottles.bottles.first { $0.id == incoming.id }?.opened ?? false)
        XCTAssertThrowsError(try bottles.open(incoming, breeds: breeds, moments: 5, now: later), "한 번만 열려요")

        let reopened = BottleStore(directory: folder)
        reopened.load()
        XCTAssertEqual(reopened.bottles, bottles.bottles)
    }
}
