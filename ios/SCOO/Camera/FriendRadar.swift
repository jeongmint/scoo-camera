import Foundation
import CoreLocation

/// 주변 친구 거리: while the camera is open and the user turned it on, shares a rounded position (about 100 m)
/// with friends only and shows where friends are, as a direction and a distance on the camera.
@MainActor
final class FriendRadar: NSObject, ObservableObject {
    struct Blip: Identifiable, Equatable {
        let id: UUID
        let name: String
        let hero: String?
        let meters: Double
        /// Degrees clockwise from north, from me to the friend.
        let bearing: Double
    }

    @Published private(set) var blips: [Blip] = []
    /// Where the phone points, degrees clockwise from north.
    @Published private(set) var heading: Double = 0
    @Published var problem: String?
    @Published private(set) var isOn = false

    /// Friends farther than this are left out.
    static let range: Double = 5_000
    nonisolated static let refresh: Duration = .seconds(60)

    private let manager = CLLocationManager()
    private var here: CLLocation?
    private var loop: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.headingFilter = 3
    }

    func start() {
        guard !isOn else { return }
        guard SupabaseConfig.isConfigured else { problem = "서버에 연결해야 주변 친구를 볼 수 있어요."; return }
        isOn = true
        problem = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            problem = "설정에서 위치를 허용하면 주변 친구가 보여요."
            isOn = false
            return
        default: break
        }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync()
                try? await Task.sleep(for: Self.refresh)
            }
        }
    }

    /// Stops sharing and removes my position from the server.
    func stop() {
        guard isOn else { return }
        isOn = false
        loop?.cancel()
        loop = nil
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        blips = []
        Task { try? await SupabaseClient.shared.call(rpc: "stop_presence", [:]) }
    }

    private func sync() async {
        guard isOn else { return }
        // Never create an account just for this: only an account that already exists shares.
        guard await SupabaseClient.shared.currentUserID != nil else {
            problem = "설정에서 서버에 연결하면 주변 친구가 보여요."
            return
        }
        // Wait briefly for the first fix.
        for _ in 0..<10 where here == nil { try? await Task.sleep(for: .milliseconds(500)) }
        guard let here else { return }
        struct Row: Decodable {
            let friend_id: UUID
            let nickname: String?
            let hero: String?
            let lat: Double
            let lng: Double
        }
        do {
            try await SupabaseClient.shared.call(rpc: "share_presence", ["p_lat": here.coordinate.latitude, "p_lng": here.coordinate.longitude])
            let rows = try await SupabaseClient.shared.rpc("friends_nearby", [:], as: [Row].self)
            blips = rows.compactMap { row in
                let there = CLLocation(latitude: row.lat, longitude: row.lng)
                let meters = here.distance(from: there)
                guard meters <= Self.range else { return nil }
                return Blip(id: row.friend_id, name: row.nickname ?? "친구", hero: row.hero, meters: meters,
                            bearing: Self.bearing(from: here.coordinate, to: there.coordinate))
            }
            .sorted { $0.meters < $1.meters }
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Initial great-circle bearing, degrees clockwise from north (0..<360).
    nonisolated static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let deltaLng = (b.longitude - a.longitude) * .pi / 180
        let y = sin(deltaLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLng)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// "80m", "1.2km". Positions are rounded to about 100 m, so short distances say "바로 근처".
    nonisolated static func label(_ meters: Double) -> String {
        if meters < 150 { return "바로 근처" }
        if meters < 1_000 { return "\(Int((meters / 10).rounded()) * 10)m" }
        return String(format: "%.1fkm", meters / 1_000)
    }
}

extension FriendRadar: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.here = last }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.heading = value }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .denied || status == .restricted {
                self.problem = "설정에서 위치를 허용하면 주변 친구가 보여요."
                self.stop()
            }
        }
    }
}
