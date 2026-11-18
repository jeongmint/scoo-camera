import XCTest
@testable import SCOO

final class BottleRemindersTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func bottle(_ direction: Bottle.Direction, arrives offset: TimeInterval, news: Bool = false, opened: Bool = false) -> Bottle {
        Bottle(id: UUID(), direction: direction, parentA: "nyamo", parentB: "mori", origin: "마포구",
               sentAt: now.addingTimeInterval(-3600), arrivesAt: now.addingTimeInterval(offset), wantsNews: news, opened: opened)
    }

    func testIncomingBottleRingsWhenItArrives() {
        let incoming = bottle(.incoming, arrives: 600)
        let plan = BottleReminders.plan([incoming], now: now, fast: false)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].date, incoming.arrivesAt)
        XCTAssertEqual(plan[0].title, "유리병이 도착했어요")
        XCTAssertTrue(plan[0].body.contains("마포구"))
    }

    func testArrivedOrOpenedBottlesStayQuiet() {
        let arrived = bottle(.incoming, arrives: -10)
        let opened = bottle(.incoming, arrives: 600, opened: true)
        XCTAssertTrue(BottleReminders.plan([arrived, opened], now: now, fast: false).isEmpty)
    }

    func testEveryFutureLetterOfASentBabyIsScheduledInOrder() {
        let sent = bottle(.outgoing, arrives: 600, news: true)
        let plan = BottleReminders.plan([sent], now: now, fast: false)
        XCTAssertEqual(plan.count, BottleRules.maxLetters)
        XCTAssertEqual(plan.map(\.date), (0..<BottleRules.maxLetters).map { BottleRules.letterDate(sent, index: $0, fast: false) })
        XCTAssertEqual(plan[0].body, BottleRules.letterText(sent, index: 0))
        XCTAssertEqual(Set(plan.map(\.id)).count, plan.count, "ids must be unique so rescheduling replaces")
    }

    func testLettersAlreadyReadAreNotScheduledAgain() {
        // arrived three days ago: the first two letters (6 h, 2 d 6 h) are past
        let sent = bottle(.outgoing, arrives: -3 * 24 * 3600, news: true)
        XCTAssertEqual(BottleReminders.plan([sent], now: now, fast: false).count, BottleRules.maxLetters - 2)
        XCTAssertTrue(BottleReminders.plan([bottle(.outgoing, arrives: 600)], now: now, fast: false).isEmpty, "no news asked")
    }

    func testPlanStaysUnderTheSystemLimit() {
        let many = (0..<20).map { _ in bottle(.outgoing, arrives: 600, news: true) }
        XCTAssertEqual(BottleReminders.plan(many, now: now, fast: false).count, BottleReminders.limit)
    }

    func testLettersReadInTheAppMatchTheSchedule() {
        let sent = bottle(.outgoing, arrives: -3 * 24 * 3600, news: true)
        XCTAssertEqual(BottleRules.letters(for: [sent], now: now, fast: false).count, 2)
    }
}
