import XCTest
@testable import SCOO

final class PersonalityTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func photo(hour: Int = 14, food: Bool = false, bonus: Int = 3, place: (Double, Double)? = nil, day: Int = 1) -> PhotoRecord {
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
        return PhotoRecord(id: UUID(), date: date, filename: "x.jpg", filter: "Eternal", isFood: food, mode: .auto,
                           experience: 12, bonus: bonus, classificationNote: "",
                           location: place.map { PhotoLocation(latitude: $0.0, longitude: $0.1) })
    }

    func testFewPhotosMeansStillGettingToKnow() {
        XCTAssertEqual(Personality.of([photo(), photo()], calendar: calendar).title, "알아가는 중")
    }

    func testTraitsFollowHabits() {
        XCTAssertEqual(Personality.of((0..<6).map { photo(food: $0 < 3) }, calendar: calendar).title, "먹보")
        XCTAssertEqual(Personality.of((0..<6).map { _ in photo(hour: 22) }, calendar: calendar).title, "올빼미")
        XCTAssertEqual(Personality.of((0..<6).map { _ in photo(hour: 7) }, calendar: calendar).title, "아침형")
        XCTAssertEqual(Personality.of((0..<6).map { _ in photo(bonus: 9) }, calendar: calendar).title, "감성파")
        let travels = (0..<9).map { photo(place: (37.5 + Double($0) * 0.05, 127.0)) }
        XCTAssertEqual(Personality.of(travels, calendar: calendar).title, "탐험가")
        XCTAssertEqual(Personality.of((0..<6).map { _ in photo() }, calendar: calendar).title, "느긋한 산책러")
    }

    func testKeepsakeIsTheChosenPhotoOrTheBrightest() {
        let dim = photo(bonus: 2, day: 1), bright = photo(bonus: 9, day: 2), alsoBright = photo(bonus: 9, day: 3)
        let photos = [alsoBright, bright, dim]
        XCTAssertEqual(Keepsake.photo(in: photos, chosen: dim.id.uuidString), dim)
        XCTAssertEqual(Keepsake.photo(in: photos, chosen: ""), bright, "같은 점수면 먼저 찍은 순간")
        XCTAssertEqual(Keepsake.photo(in: photos, chosen: UUID().uuidString), bright, "고른 사진이 지워졌으면 다시 골라요")
        XCTAssertNil(Keepsake.photo(in: [], chosen: ""))
    }

    func testFilmCaptionReadsTheDay() {
        XCTAssertEqual(FilmStrip.caption(friend: "냐모", photos: [photo(food: true), photo()]), "냐모와 맛있는 것만 잔뜩 본 날")
        XCTAssertEqual(FilmStrip.caption(friend: "모리", photos: (0..<4).map { _ in photo() }), "모리와 부지런히 담은 하루")
        XCTAssertEqual(FilmStrip.caption(friend: "모리", photos: [photo()]), "모리와 함께 본 오늘")
    }
}
