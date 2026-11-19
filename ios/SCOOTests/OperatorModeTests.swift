import XCTest
@testable import SCOO

final class OperatorModeTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "OperatorModeTests-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testOrdinaryAccountsLoseTheTestSwitches() {
        let defaults = freshDefaults()
        OperatorMode.apply(true, defaults: defaults)
        defaults.set(true, forKey: "unlockAllFriends")
        defaults.set(true, forKey: "bottleFastMode")
        XCTAssertTrue(defaults.bool(forKey: OperatorMode.key))

        OperatorMode.apply(false, defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: OperatorMode.key))
        XCTAssertFalse(defaults.bool(forKey: "unlockAllFriends"), "모든 친구 열기는 운영자만")
        XCTAssertFalse(defaults.bool(forKey: "bottleFastMode"), "1분 배송은 운영자만")
    }

    func testOperatorsKeepTheirSwitches() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: "bottleFastMode")
        OperatorMode.apply(true, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: "bottleFastMode"))
    }
}
