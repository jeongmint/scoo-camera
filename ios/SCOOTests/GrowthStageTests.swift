import XCTest
@testable import SCOO

final class GrowthStageTests: XCTestCase {
    func testThreeStagesByPhotosSinceHatching() {
        XCTAssertEqual(GrowthStage.of(photos: 0), .baby)
        XCTAssertEqual(GrowthStage.of(photos: BreedRules.photosToGrowing - 1), .baby)
        XCTAssertEqual(GrowthStage.of(photos: BreedRules.photosToGrowing), .growing)
        XCTAssertEqual(GrowthStage.of(photos: BreedRules.photosToGrow), .bloom)
        XCTAssertEqual(GrowthStage.photosToNext(after: 2), BreedRules.photosToGrowing - 2)
        XCTAssertEqual(GrowthStage.photosToNext(after: BreedRules.photosToGrowing), BreedRules.photosToGrow - BreedRules.photosToGrowing)
        XCTAssertEqual(GrowthStage.photosToNext(after: 99), 0)
        // bloom is the old "adult"
        let baby = Breed(id: UUID(), parentA: "mori", parentB: "nyamo", born: Date(), bornAtMoment: 3)
        XCTAssertEqual(baby.stage(moments: 3 + BreedRules.photosToGrow) == .bloom, baby.isAdult(moments: 3 + BreedRules.photosToGrow))
    }

    func testOnlyBabiesInBloomCanBeParents() {
        let young = Breed(id: UUID(), parentA: "mori", parentB: "nyamo", born: Date(), bornAtMoment: 10)
        let grown = Breed(id: UUID(), parentA: "tori", parentB: "sia", born: Date(), bornAtMoment: 0)
        let parents = BreedRules.parents(species: [Species.find("mori")!, Species.find("kuru")!], breeds: [young, grown], moments: 12)
        XCTAssertEqual(parents.map(\.id), ["mori", "kuru", grown.parentID])
        XCTAssertTrue(grown.parentID.hasPrefix("b_"))
        XCTAssertNotNil(grown.parentID.range(of: "^[a-z0-9_]{1,30}$", options: .regularExpression), "the server accepts it")
    }

    func testRebredBabyKeepsRootsAndGeneration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = BreedStore(directory: directory)
        let first = try store.hatch(a: "tori", b: "sia", moments: 0)
        let grownUp = BreedParent(first)
        let kuru = BreedParent(Species.find("kuru")!)
        let second = try store.hatch(grownUp, kuru, moments: BreedRules.photosToGrow)
        XCTAssertEqual(second.generation, 2)
        XCTAssertEqual(second.mother?.id, "tori", "shape comes from parent A's root species")
        XCTAssertEqual(second.father?.id, "kuru")
        XCTAssertEqual(second.artA, first.key)
        XCTAssertEqual(second.title, "\(first.title) × 쿠르")
        // a third generation is the last one
        let third = BreedParent(Breed(id: UUID(), parentA: "x", parentB: "y", born: Date(), bornAtMoment: 0, generation: 3))
        XCTAssertEqual(BreedRules.problem(a: third, b: kuru, available: [third, kuru]), .tooDeep)
        XCTAssertNil(BreedRules.problem(a: grownUp, b: kuru, available: [grownUp, kuru]))
        XCTAssertEqual(BreedRules.problem(a: grownUp, b: grownUp, available: [grownUp]), .sameParent)
    }

    func testOldRecordsStillDecode() throws {
        let old = #"[{"id":"aaaaaaaa-0000-4000-8000-000000000001","parentA":"tori","parentB":"sia","born":0,"bornAtMoment":2}]"#
        let breeds = try JSONDecoder().decode([Breed].self, from: Data(old.utf8))
        XCTAssertNil(breeds[0].generation)
        XCTAssertEqual(breeds[0].title, "토리 × 시아")
    }
}
