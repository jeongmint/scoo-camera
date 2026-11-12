import XCTest
@testable import SCOO

final class GrowthRulesTests: XCTestCase {
    func testLevelBoundaryAndRemainder() {
        XCTAssertEqual(GrowthRules.growth(for: 99).level, 1)
        XCTAssertEqual(GrowthRules.growth(for: 100).level, 2)
        XCTAssertEqual(GrowthRules.growth(for: 135).progress, 35)
        XCTAssertGreaterThan(GrowthRules.growth(for: 100).size, GrowthRules.growth(for: 0).size)
        XCTAssertEqual(GrowthRules.growth(for: -1).level, 1)
    }
    func testFoodRewardAndBonusBounds() {
        XCTAssertEqual(GrowthRules.reward(isFood: true, bonus: 6), 26)
        XCTAssertEqual(GrowthRules.reward(isFood: false, bonus: 6), 18)
        XCTAssertEqual(GrowthRules.reward(isFood: true, bonus: 100), 30)
        XCTAssertEqual(GrowthRules.reward(isFood: false, bonus: -2), 12)
    }
    func testExposureAndDetailBonus() {
        let detailed = (0..<256).map { Double($0 % 2 == 0 ? 80 : 180) }
        let dark = [Double](repeating: 0, count: 256)
        let blank = [Double](repeating: 132, count: 256)
        let score = GrowthRules.qualityBonus(luminance: detailed, width: 16, height: 16)
        XCTAssertGreaterThan(score, GrowthRules.qualityBonus(luminance: dark, width: 16, height: 16))
        XCTAssertGreaterThan(score, GrowthRules.qualityBonus(luminance: blank, width: 16, height: 16))
        XCTAssertLessThanOrEqual(score, 10)
        XCTAssertEqual(GrowthRules.qualityBonus(luminance: [], width: 0, height: 0), 0)
    }
}
