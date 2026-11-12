import XCTest
@testable import SCOO

final class EternalInteractionTests: XCTestCase {
    func testOnlyEternalIsOffered() {
        XCTAssertEqual(FilmLook.allCases, [.eternal])
        XCTAssertEqual(FilmLook.eternal.rawValue, "Eternal")
    }

    func testNeutralShadowsAreCoolAndBlackStaysBlack() {
        let black = EternalPalette.map(.init(r: 0, g: 0, b: 0))
        XCTAssertEqual(black, .init(r: 0, g: 0, b: 0))
        let gray = EternalPalette.map(.init(r: 0.18, g: 0.18, b: 0.18))
        XCTAssertGreaterThan(gray.b, gray.g)
        XCTAssertGreaterThan(gray.g, gray.r)
        let white = EternalPalette.map(.init(r: 1, g: 1, b: 1))
        XCTAssertGreaterThan(white.r, white.b)
        XCTAssertLessThanOrEqual(white.r, 1)
    }

    func testToneCurveIsMonotonicAndCubeHasRGBAFloatLayout() {
        var previous = 0.0
        for i in 0...1000 {
            let value = EternalPalette.curve(Double(i) / 1000)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
        let n = EternalPalette.dimension
        XCTAssertEqual(EternalPalette.cubeData.count, n * n * n * 4 * MemoryLayout<Float>.size)
        let values = EternalPalette.cubeData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        XCTAssertEqual(Array(values.prefix(4)), [0, 0, 0, 1])
        let red = EternalPalette.map(.init(r: 1, g: 0, b: 0))
        XCTAssertEqual(values[(n - 1) * 4], Float(red.r), accuracy: 0.00001)
        XCTAssertTrue(values.enumerated().allSatisfy { $0.offset % 4 != 3 || $0.element == 1 })
    }

    func testMoriIsKeptInsideSafeAreaAndOutOfControls() {
        let value = MoriPlacement(x: -10, y: 10).clamped(width: 390, height: 844, top: 139, bottom: 124, radius: 45)
        XCTAssertGreaterThanOrEqual(value.x * 390, 56.999)
        XCTAssertLessThanOrEqual(value.y * 844, 844 - 124 - 45 - 20 + 0.001)
        let offscreen = MoriPlacement(x: .nan, y: .infinity).clamped(width: 390, height: 844, top: 139, bottom: 124, radius: 45)
        XCTAssertTrue(offscreen.x.isFinite && offscreen.y.isFinite)
        XCTAssertEqual(MoriPlacement(x: 1, y: 1).clamped(width: 0, height: 0, top: 0, bottom: 0, radius: 45), .initial)
    }

    func testNormalizedMoriPositionSurvivesViewportChanges() {
        let saved = MoriPlacement(x: 0.75, y: 0.60)
        let first = saved.clamped(width: 390, height: 844, top: 139, bottom: 124, radius: 45)
        let second = saved.clamped(width: 430, height: 932, top: 139, bottom: 124, radius: 45)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first, saved)
    }
}
