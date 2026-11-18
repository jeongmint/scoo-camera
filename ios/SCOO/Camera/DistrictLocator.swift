import Foundation
import CoreLocation

/// Works out which 시군구 the user is in (anywhere in Korea), and where a photo was taken.
/// Positions are requested one at a time (no tracking). For the district the coordinate goes to Apple's geocoder;
/// photo positions are kept only in the app's local garden file for the map guestbook.
@MainActor
final class DistrictLocator: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Failure: Error, Equatable {
        case denied        // permission refused or restricted
        case unavailable   // no position or no address in time
        case outside       // an address was found but no 시군구 in it (outside Korea)

        var reason: String {
            switch self {
            case .denied: "위치 권한이 꺼져 있어요. 위치를 허용하면 동네 친구가 와요."
            case .unavailable: "위치를 확인하지 못했어요."
            case .outside: "국내 시군구를 찾지 못했어요."
            }
        }
    }

    private let manager = CLLocationManager()
    private var authorization: CheckedContinuation<Void, Never>?
    private var position: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters   // enough for a district and a map pin
    }

    func currentRegion() async -> Result<Region, Failure> {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorization = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: break
        default: return .failure(.denied)
        }
        guard let location = await locate() else { return .failure(.unavailable) }
        do {
            let marks = try await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR"))
            let texts = marks.flatMap { mark in
                [mark.subLocality, mark.locality, mark.subAdministrativeArea, mark.administrativeArea, mark.name, mark.thoroughfare]
            }.compactMap { $0 }
            if let region = Regions.match(in: texts) { return .success(region) }
            return .failure(texts.isEmpty ? .unavailable : .outside)
        } catch {
            return .failure(.unavailable)
        }
    }

    /// The 시군구 a photo was taken in (nil outside Korea or when the geocoder cannot tell).
    func region(at place: PhotoLocation) async -> Region? {
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        guard let marks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) else {
            return nil
        }
        let texts = marks.flatMap { mark in
            [mark.subLocality, mark.locality, mark.subAdministrativeArea, mark.administrativeArea, mark.name, mark.thoroughfare]
        }.compactMap { $0 }
        return Regions.match(in: texts)
    }

    /// Where the user is right now, for the map guestbook: a recent fix if there is one, otherwise a quick new one.
    /// Never asks for permission (the first launch already did) and gives up after a few seconds.
    func quickLocation() async -> PhotoLocation? {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: break
        default: return nil
        }
        if let last = manager.location, -last.timestamp.timeIntervalSinceNow < 120, last.horizontalAccuracy < 1_000 {
            return PhotoLocation(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        }
        guard position == nil, let fix = await locate(timeout: 4) else { return nil }
        return PhotoLocation(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
    }

    /// One position fix, giving up after `timeout` seconds.
    private func locate(timeout: Double = 10) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            position = continuation
            manager.requestLocation()
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.finishLocate(nil)
            }
        }
    }

    private func finishLocate(_ location: CLLocation?) {
        guard let continuation = position else { return }
        position = nil
        continuation.resume(returning: location)
    }

    private func finishAuthorization() {
        guard manager.authorizationStatus != .notDetermined, let continuation = authorization else { return }
        authorization = nil
        continuation.resume()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.finishAuthorization() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in self.finishLocate(latest) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finishLocate(nil) }
    }
}
