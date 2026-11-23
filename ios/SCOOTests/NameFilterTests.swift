import XCTest
@testable import SCOO

final class NameFilterTests: XCTestCase {
    func testPlainNamesAreFine() {
        for name in ["멜나", "콩이", "Momo", "모리 2세", "보송보송이", "귤"] {
            XCTAssertNil(NameFilter.problem(name), name)
        }
        XCTAssertEqual(NameFilter.clean("  콩   이 "), "콩 이")
    }

    func testShapeRules() {
        XCTAssertEqual(NameFilter.problem("   "), .empty)
        XCTAssertEqual(NameFilter.problem("아주아주긴이름입니다"), .tooLong(NameFilter.maxLength))
        XCTAssertNil(NameFilter.problem("아주아주긴이름입니다", maxLength: 12), "닉네임은 조금 더 길게")
        XCTAssertEqual(NameFilter.problem("ㅋㅋㅋ"), .characters, "완성되지 않은 글자")
        XCTAssertEqual(NameFilter.problem("콩이🐶"), .characters, "그림 문자")
        XCTAssertEqual(NameFilter.problem("www.x"), .characters)
        XCTAssertEqual(NameFilter.problem("01012345"), .numbers, "전화번호처럼 보이는 숫자")
        XCTAssertEqual(NameFilter.problem("콩1234"), .numbers)
    }

    func testRudeWordsAreCaughtEvenWhenHidden() {
        for name in ["시발", "시 발", "시1발", "개새끼야", "섹스", "FUCK", "f u c k", "운영자"] {
            XCTAssertEqual(NameFilter.problem(name), .word, name)
        }
    }

    func testBabyNamesBlendTheParents() {
        XCTAssertEqual(NameFilter.blend("멜로", "루나"), "멜나")
        XCTAssertEqual(NameFilter.blend("귤", "도도"), "귤도")
        let taken = Set(Species.all.map { $0.name.split(separator: " ").last.map(String.init) ?? $0.name })
        for a in Species.all {
            for b in Species.all where a.id != b.id {
                let name = NameFilter.blend(a.name, b.name)
                XCTAssertFalse(taken.contains(name), "\(a.name) × \(b.name) → \(name)")
                XCTAssertNil(NameFilter.problem(name), "\(a.name) × \(b.name) → \(name)")
            }
        }
        let baby = Breed(id: UUID(), parentA: "mello", parentB: "luna", born: Date(), bornAtMoment: 0)
        XCTAssertEqual(baby.name, "멜나")
        var named = baby
        named.nickname = "콩이"
        XCTAssertEqual(named.name, "콩이")
        XCTAssertEqual(named.title, "멜로 × 루나", "부모 표시는 그대로")
    }

    @MainActor
    func testRenamingKeepsOnlyAllowedNames() throws {
        let suite = "NameFilterTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let friends = FriendStore(defaults: defaults)
        let mello = friends.add(Species.find("mello")!, how: .starter, origin: nil)
        try friends.rename(mello.id, to: "  콩이 ")
        XCTAssertEqual(friends.friends.first?.name, "콩이")
        XCTAssertThrowsError(try friends.rename(mello.id, to: "시발"))
        XCTAssertEqual(friends.friends.first?.name, "콩이", "거절된 이름은 저장되지 않아요")
        try friends.rename(mello.id, to: "")
        XCTAssertEqual(friends.friends.first?.name, "멜로", "비우면 원래 이름")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let babies = BreedStore(directory: directory)
        let baby = try babies.hatch(a: "mello", b: "luna", moments: 0)
        try babies.rename(baby.id, to: "별이")
        XCTAssertEqual(babies.breeds.first?.name, "별이")
        XCTAssertThrowsError(try babies.rename(baby.id, to: "ㅗㅗ"))
    }
}
