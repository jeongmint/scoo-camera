import XCTest
@testable import SCOO

final class MoriExpressionTests: XCTestCase {
    private func face(food: Bool = false, bonus: Int = 0, levelUp: Bool = false,
                      previous: MoriExpression? = nil, roll: Double = 0.1) -> MoriExpression {
        MoriExpression.reaction(isFood: food, bonus: bonus, leveledUp: levelUp, previous: previous, roll: roll)
    }

    func testFoodIsAlwaysYum() {
        XCTAssertEqual(face(food: true, bonus: 10, levelUp: true), .yum)
        XCTAssertEqual(face(food: true, previous: .yum), .yum)
    }

    func testLevelUpIsSmile() {
        XCTAssertEqual(face(bonus: 10, levelUp: true), .smile)
    }

    func testHighLightAndDetailScoreIsAwe() {
        XCTAssertEqual(face(bonus: MoriExpression.aweBonus), .awe)
        XCTAssertEqual(face(bonus: 10), .awe)
        XCTAssertNotEqual(face(bonus: MoriExpression.aweBonus - 1), .awe)
    }

    func testOrdinaryPhotoVariesBetweenSmileAndSurpriseWithoutRepeating() {
        XCTAssertEqual(face(roll: 0.0), .smile)
        XCTAssertEqual(face(roll: 0.99), .surprised)
        XCTAssertEqual(face(previous: .smile, roll: 0.0), .surprised)
        XCTAssertEqual(face(previous: .surprised, roll: 0.99), .smile)
        for roll in stride(from: 0.0, to: 1.0, by: 0.05) {
            let result = face(previous: .smile, roll: roll)
            XCTAssertNotEqual(result, .smile)
            XCTAssertTrue([.smile, .surprised].contains(result))
        }
    }

    func testOutOfRangeRollIsHandled() {
        XCTAssertEqual(face(roll: -3), .smile)
        XCTAssertEqual(face(roll: 5), .surprised)
    }
}
