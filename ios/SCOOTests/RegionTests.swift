import XCTest
@testable import SCOO

final class RegionTests: XCTestCase {
    func testEveryPlaceInKoreaHasAFriend() {
        XCTAssertEqual(Province.allCases.count, 17)
        XCTAssertEqual(Regions.all.count, 229)
        XCTAssertEqual(Set(Regions.all.map(\.id)).count, 229, "ids are unique (중구, 동구, 고성군 … live in several 시도)")
        XCTAssertTrue(Regions.all.allSatisfy { $0.friend != nil }, "every friend id is a real species")
        XCTAssertTrue(Regions.all.allSatisfy { $0.friend?.isEvent == false }, "the snowman is an event friend, not a local one")
        let living = Set(Regions.all.map(\.friendID))
        XCTAssertEqual(living, Set(Species.all.filter { !$0.isEvent }.map(\.id)), "all 37 regular friends live somewhere")
        XCTAssertTrue(Regions.all.allSatisfy { $0.candidates.count == 5 && Set($0.candidates).count == 5 }, "다섯 친구, 겹치지 않게")
        XCTAssertTrue(Regions.all.allSatisfy { $0.candidates.first == $0.friendID }, "그 동네 친구가 첫째")
        XCTAssertTrue(Regions.all.allSatisfy { $0.candidateSpecies.count == 5 && !$0.candidateSpecies.contains { $0.isEvent } })
    }

    func testRarityHasCommonAndRareFriends() {
        let counts = Dictionary(grouping: Regions.all, by: \.friendID).mapValues(\.count)
        XCTAssertGreaterThanOrEqual(counts.values.min() ?? 0, 1)
        // the Seoul-only friends live in exactly one 구 each
        for id in ["bosong", "chiru", "cro", "inky", "momo", "mumu", "pico", "posil", "rora"] {
            XCTAssertEqual(Regions.homes(of: id).map(\.province), [.seoul], id)
        }
        XCTAssertLessThanOrEqual(counts.values.max() ?? 0, 20)
        XCTAssertEqual(Regions.homes(of: "tangerine").map(\.title).contains("제주 서귀포시"), true)
    }

    func testGeocoderAnswersFindThePlace() {
        XCTAssertEqual(Regions.match(in: ["서울특별시", "강남구", "역삼동"])?.id, "서울 강남구")
        XCTAssertEqual(Regions.match(in: ["대한민국 서울특별시 종로구 사직동 1"])?.id, "서울 종로구")
        XCTAssertEqual(Regions.match(in: ["경기도", "수원시", "팔달구", "행궁동"])?.id, "경기 수원시")
        XCTAssertEqual(Regions.match(in: ["경기도", "광주시"])?.id, "경기 광주시", "경기 광주시 is not 광주광역시")
        XCTAssertEqual(Regions.match(in: ["광주광역시", "북구"])?.id, "광주 북구")
        XCTAssertEqual(Regions.match(in: ["부산광역시", "강서구"])?.id, "부산 강서구", "서구 inside 강서구 must not match")
        XCTAssertEqual(Regions.match(in: ["강원도", "고성군"])?.id, "강원 고성군", "old province name")
        XCTAssertEqual(Regions.match(in: ["경상남도", "고성군"])?.id, "경남 고성군")
        XCTAssertEqual(Regions.match(in: ["세종특별자치시", "조치원읍"])?.id, "세종")
        XCTAssertEqual(Regions.match(in: ["가평군"])?.id, "경기 가평군", "a name found once in the country")
        XCTAssertNil(Regions.match(in: ["중구"]), "ambiguous without a province")
        XCTAssertNil(Regions.match(in: ["Tokyo", "Shibuya"]))
        XCTAssertNil(Regions.match(in: ["강남대로", "서울특별시"]))
    }

    func testStoredSeoulNamesStillResolve() {
        XCTAssertEqual(Regions.resolve("마포구")?.id, "서울 마포구")
        XCTAssertEqual(Regions.resolve("서울 마포구")?.id, "서울 마포구")
        XCTAssertNil(Regions.resolve("없는구"))
    }

    func testNeighboursShareFriends() {
        // 마포구 and 서대문구 are next to each other: their five overlap.
        let mapo = Set(Regions.find("서울 마포구")!.candidates), seodaemun = Set(Regions.find("서울 서대문구")!.candidates)
        XCTAssertGreaterThanOrEqual(mapo.intersection(seodaemun).count, 2)
        XCTAssertTrue(Regions.find("제주 서귀포시")!.candidates.contains("tangerine"))
        let counts = Dictionary(grouping: Regions.all.flatMap(\.candidates), by: { $0 }).mapValues(\.count)
        XCTAssertEqual(counts.count, 37, "every regular character can be someone's first friend somewhere")
    }
}
