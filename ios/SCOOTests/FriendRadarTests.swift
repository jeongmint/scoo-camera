import XCTest
import CoreLocation
@testable import SCOO

final class FriendRadarTests: XCTestCase {
    func testBearingPointsTheRightWay() {
        let here = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        XCTAssertEqual(FriendRadar.bearing(from: here, to: .init(latitude: 37.60, longitude: 126.9780)), 0, accuracy: 0.5)
        XCTAssertEqual(FriendRadar.bearing(from: here, to: .init(latitude: 37.5665, longitude: 127.02)), 90, accuracy: 0.5)
        XCTAssertEqual(FriendRadar.bearing(from: here, to: .init(latitude: 37.53, longitude: 126.9780)), 180, accuracy: 0.5)
        XCTAssertEqual(FriendRadar.bearing(from: here, to: .init(latitude: 37.5665, longitude: 126.93)), 270, accuracy: 0.5)
    }

    func testDistanceLabelsMatchTheRounding() {
        XCTAssertEqual(FriendRadar.label(90), "바로 근처")
        XCTAssertEqual(FriendRadar.label(432), "430m")
        XCTAssertEqual(FriendRadar.label(1_260), "1.3km")
    }
}
