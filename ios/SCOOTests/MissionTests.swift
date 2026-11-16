import XCTest
@testable import SCOO

final class MissionTests: XCTestCase {
    func testMissionsAreDistinct() {
        XCTAssertEqual(Set(DailyMission.all.map(\.id)).count, DailyMission.all.count)
        XCTAssertTrue(DailyMission.all.allSatisfy { !$0.terms.isEmpty })
    }

    func testSameDaySameMissionAndNeighbouringDaysDiffer() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 8))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 23))!
        let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 8))!
        XCTAssertEqual(DailyMission.of(morning, calendar: calendar), DailyMission.of(night, calendar: calendar))
        XCTAssertNotEqual(DailyMission.of(morning, calendar: calendar), DailyMission.of(tomorrow, calendar: calendar))
        XCTAssertEqual(DailyMission.dayKey(morning, calendar: calendar), "2026-11-16")
        // over a month every subject comes up
        let month = (0..<31).map { DailyMission.of(morning.addingTimeInterval(Double($0) * 86_400), calendar: calendar).id }
        XCTAssertEqual(Set(month).count, DailyMission.all.count)
    }

    func testLabelsMatchLikeTheFoodGuess() throws {
        let sky = try XCTUnwrap(DailyMission.all.first { $0.id == "sky" })
        XCTAssertTrue(sky.matches(["structure", "sky"]))
        XCTAssertTrue(sky.matches(["Blue Sky"]))
        XCTAssertFalse(sky.matches(["skyscraper"]), "단어 일부만 같으면 안 돼요")
        let cat = try XCTUnwrap(DailyMission.all.first { $0.id == "cat" })
        XCTAssertTrue(cat.matches(["animal", "cat"]))
        XCTAssertFalse(cat.matches(["catamaran"]))
        XCTAssertFalse(cat.matches([]))
    }
}
