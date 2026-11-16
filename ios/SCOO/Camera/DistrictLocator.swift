import Foundation
import CoreLocation

/// Works out which Seoul district the user is in, once, when asked.
/// Only a rough position is requested, nothing is stored, and no tracking starts.
/// The coordinate goes to Apple's geocoder to get an address name; it is not sent anywhere else.
@MainActor
final class DistrictLocator: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Failure: Error, Equatable {
        case denied        // permission refused or restricted
        case unavailable   // no position or no address in time
        case outsideSeoul  // an address was found but it is not one of the 25 districts

        var reason: String {
            switch self {
            case .denied: "위치 권한이 꺼져 있어요. 위치를 허용하면 동네 친구가 와요."
            case .unavailable: "위치를 확인하지 못했어요."
            case .outsideSeoul: "서울 밖이에요."
            }
        }
    }

    private let manager = CLLocationManager()
    private var authorization: CheckedContinuation<Void, Never>?
    private var position: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer   // a district is enough
    }

    func currentDistrict() async -> Result<SeoulDistrict, Failure> {
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
            if let district = SeoulDistrict.match(in: texts) { return .success(district) }
            return .failure(texts.isEmpty ? .unavailable : .outsideSeoul)
        } catch {
            return .failure(.unavailable)
        }
    }

    /// One position fix, giving up after ten seconds.
    private func locate() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            position = continuation
            manager.requestLocation()
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
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
