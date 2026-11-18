import XCTest
import UIKit
@testable import SCOO

final class BreedTests: XCTestCase {
    // MARK: Family

    func testFamilyHasTwentyFiveWithImages() {
        XCTAssertEqual(Species.all.count, 42)
        XCTAssertEqual(Set(Species.all.map(\.id)).count, 42)
        XCTAssertEqual(Species.all.filter(\.isEvent).map(\.id), ["happy", "bomi", "soru", "doto"])
        XCTAssertTrue(Species.all.filter(\.isEvent).allSatisfy { $0.season != nil }, "이벤트 친구는 모두 계절 친구")
        for species in Species.all {
            XCTAssertNotNil(UIImage(named: species.assetName), "\(species.name) 이미지가 없어요")
        }
        XCTAssertNotNil(UIImage(named: "Daisy"))
    }

    func testOwnedFriendsAreWhatTheUserHasUnlessEverythingIsOpen() {
        let mine = ["kuru", "happy"].compactMap(Species.find)
        XCTAssertEqual(Species.owned(mine, unlockAll: false).map(\.id), ["kuru", "happy"])
        XCTAssertEqual(Species.owned([], unlockAll: false), [])
        XCTAssertEqual(Species.owned([], unlockAll: true).count, 42)
    }

    // MARK: Rules

    func testBreedingNeedsTwoDifferentOwnedParents() {
        let owned = ["mori", "happy"].compactMap(Species.find)
        XCTAssertEqual(BreedRules.problem(a: nil, b: "happy", owned: owned), .missingParent)
        XCTAssertEqual(BreedRules.problem(a: "mori", b: "mori", owned: owned), .sameParent)
        XCTAssertEqual(BreedRules.problem(a: "mori", b: "sia", owned: owned), .notOwned)
        XCTAssertNil(BreedRules.problem(a: "mori", b: "happy", owned: owned))
        XCTAssertNil(BreedRules.problem(a: "happy", b: "mori", owned: owned))
    }

    func testBabyGrowsIntoAnAdultAfterEnoughPhotos() {
        let baby = Breed(id: UUID(), parentA: "tori", parentB: "sia", born: Date(), bornAtMoment: 40)
        XCTAssertEqual(baby.key, "tori-sia")
        XCTAssertEqual(baby.babyAsset, "Breed-tori-sia")
        XCTAssertEqual(baby.adultAsset, "Adult-tori-sia")
        XCTAssertEqual(baby.title, "토리 × 시아")
        XCTAssertFalse(baby.isAdult(moments: 40))
        XCTAssertEqual(baby.photosLeft(moments: 43), BreedRules.photosToGrow - 3)
        XCTAssertTrue(baby.isAdult(moments: 40 + BreedRules.photosToGrow))
        XCTAssertEqual(baby.photosSinceBirth(moments: 10), 0, "사진이 지워져 줄어도 음수가 되지 않아요")
    }

    @MainActor
    func testStoreKeepsBabiesInItsOwnFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BreedStore(directory: folder)
        store.load()
        XCTAssertEqual(store.breeds, [])
        let first = try store.hatch(a: "nyamo", b: "mori", moments: 3)
        let second = try store.hatch(a: "kuru", b: "gwiyo", moments: 5)
        XCTAssertEqual(store.breeds.map(\.id), [second.id, first.id], "새 아기가 앞에 와요")
        let reopened = BreedStore(directory: folder)
        reopened.load()
        XCTAssertEqual(reopened.breeds, store.breeds)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("breeds.json").path))
    }

    // MARK: Daisy

    /// A 100×100 ball (radius 40) with two thin ears on top.
    private func bunny() -> [UInt8] {
        var alpha = [UInt8](repeating: 0, count: 100 * 100)
        for y in 0..<100 {
            for x in 0..<100 {
                let ball = hypot(Double(x - 50), Double(y - 58)) <= 40
                let ear = y >= 4 && y < 30 && ((x >= 30 && x < 40) || (x >= 60 && x < 70))
                if ball || ear { alpha[y * 100 + x] = 255 }
            }
        }
        return alpha
    }

    func testDaisySitsOnTheTopEdgeAtTheChosenSpot() throws {
        // x 0.15 of the 81px-wide silhouette (10...90) is column 22: no ear there, the ball's top edge is at y 30
        let place = try XCTUnwrap(DaisyPlacement.place(alpha: bunny(), width: 100, height: 100, spot: DaisySpot(x: 0.15)))
        XCTAssertEqual(place.width, 0.81 * DaisyPlacement.widthRatio, accuracy: 0.01)
        XCTAssertEqual(place.center.x, 0.22, accuracy: 0.01)
        XCTAssertEqual(place.center.y, 0.33, accuracy: 0.02, "몸 윤곽 위쪽에 살짝 걸쳐 꽂혀요")
    }

    func testBelowEarsSkipsTheEarsAndDropGoesLower() throws {
        // x 0.3 is column 34, inside the left ear (30...39)
        let onEar = try XCTUnwrap(DaisyPlacement.place(alpha: bunny(), width: 100, height: 100, spot: DaisySpot(x: 0.3)))
        let below = try XCTUnwrap(DaisyPlacement.place(alpha: bunny(), width: 100, height: 100, spot: DaisySpot(x: 0.3, belowEars: true)))
        let lower = try XCTUnwrap(DaisyPlacement.place(alpha: bunny(), width: 100, height: 100, spot: DaisySpot(x: 0.3, belowEars: true, drop: 0.25)))
        XCTAssertLessThan(onEar.center.y, 0.12, "귀 끝에 꽂혀요")
        XCTAssertGreaterThan(below.center.y, onEar.center.y + 0.1, "귀 아래 머리로 내려와요")
        XCTAssertGreaterThan(lower.center.y, below.center.y)
    }

    func testEmptyImageHasNoSpot() {
        XCTAssertNil(DaisyPlacement.place(alpha: [UInt8](repeating: 0, count: 16), width: 4, height: 4, spot: DaisySpot()))
        XCTAssertNil(DaisyPlacement.place(alpha: [1, 2], width: 4, height: 4, spot: DaisySpot()))
    }
}
