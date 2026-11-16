import XCTest
@testable import SCOO

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class SeoulDistrictTests: XCTestCase {
    func testSeoulHasTwentyFiveDistrictsEachWithAFriend() {
        XCTAssertEqual(SeoulDistrict.allCases.count, 25)
        XCTAssertEqual(Set(SeoulDistrict.allCases.map(\.rawValue)).count, 25)
        XCTAssertEqual(Set(SeoulDistrict.allCases.map(\.english)).count, 25)
        XCTAssertTrue(SeoulDistrict.allCases.allSatisfy { !$0.primary.isEvent }, "눈사람은 구의 친구가 아니에요")
        XCTAssertEqual(Set(SeoulDistrict.allCases.map(\.primary)), Set(Companion.regulars), "네 친구 모두 어딘가에 살아야 해요")
    }

    func testFindsTheDistrictInGeocoderStrings() {
        XCTAssertEqual(SeoulDistrict.match(in: ["서울특별시", "강남구", "역삼동"]), .gangnam)
        XCTAssertEqual(SeoulDistrict.match(in: ["대한민국 서울특별시 종로구 사직동 1"]), .jongno)
        XCTAssertEqual(SeoulDistrict.match(in: ["Seoul", "Mapo-gu", "Seogyo-dong"]), .mapo)
        XCTAssertEqual(SeoulDistrict.match(in: ["Seongbuk-gu"]), .seongbuk)
    }

    func testSimilarNamesAreNotMixedUp() {
        XCTAssertEqual(SeoulDistrict.match(in: ["중랑구"]), .jungnang)
        XCTAssertEqual(SeoulDistrict.match(in: ["Jungnang-gu"]), .jungnang)
        XCTAssertEqual(SeoulDistrict.match(in: ["중구"]), .jung)
        XCTAssertEqual(SeoulDistrict.match(in: ["Jung-gu"]), .jung)
        XCTAssertEqual(SeoulDistrict.match(in: ["강동구"]), .gangdong)
        XCTAssertEqual(SeoulDistrict.match(in: ["서대문구"]), .seodaemun)
        XCTAssertEqual(SeoulDistrict.match(in: ["동대문구"]), .dongdaemun)
        for district in SeoulDistrict.allCases {
            XCTAssertEqual(SeoulDistrict.match(in: [district.rawValue]), district)
            XCTAssertEqual(SeoulDistrict.match(in: [district.english]), district)
        }
    }

    func testStreetNamesAndOtherCitiesDoNotMatch() {
        XCTAssertNil(SeoulDistrict.match(in: ["강남대로", "서울특별시"]))
        XCTAssertNil(SeoulDistrict.match(in: ["부산광역시", "해운대구"]))
        XCTAssertNil(SeoulDistrict.match(in: []))
    }

    func testHometownFriendShowsUpAboutSeventyPercentAndNeverTheSnowman() {
        var generator = SeededGenerator(state: 7)
        let draws = (0..<4000).map { _ in Companion.assign(in: .gangnam, using: &generator) }
        XCTAssertFalse(draws.contains(.happy))
        let share = Double(draws.filter { $0 == SeoulDistrict.gangnam.primary }.count) / Double(draws.count)
        XCTAssertEqual(share, Companion.hometownChance, accuracy: 0.04)
        XCTAssertEqual(Set(draws), Set(Companion.regulars), "가끔은 다른 친구도 와야 해요")
    }
}
