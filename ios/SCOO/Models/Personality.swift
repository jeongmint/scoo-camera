import Foundation

/// The floating friend's personality, grown from the user's photo habits (촬영 취향에 따른 성격).
struct Personality: Equatable {
    let title: String
    /// A small habit the friend shows, in the friend's world.
    let habit: String

    /// Reads the photo history and picks the strongest trait. Needs a handful of photos before it settles.
    static func of(_ photos: [PhotoRecord], calendar: Calendar = .current) -> Personality {
        guard photos.count >= 5 else {
            return Personality(title: "알아가는 중", habit: "두리번두리번, 네가 뭘 좋아하는지 살피는 중이에요.")
        }
        let total = Double(photos.count)
        let hours = photos.map { calendar.component(.hour, from: $0.date) }
        let food = Double(photos.filter(\.isFood).count) / total
        let night = Double(hours.filter { $0 >= 20 || $0 < 5 }.count) / total
        let morning = Double(hours.filter { (5..<10).contains($0) }.count) / total
        let averageBonus = Double(photos.map(\.bonus).reduce(0, +)) / total
        // distinct places at roughly 1 km
        let places = Set(photos.compactMap { photo in
            photo.location.map { "\(Int(($0.latitude * 100).rounded()))_\(Int(($0.longitude * 100).rounded()))" }
        }).count

        if food >= 0.4 { return Personality(title: "먹보", habit: "맛있는 사진을 보면 입맛을 쩝쩝 다셔요.") }
        if places >= 8 { return Personality(title: "탐험가", habit: "새로운 곳에 가면 들떠서 빙글 돌아요.") }
        if night >= 0.4 { return Personality(title: "올빼미", habit: "밤이 되면 눈이 반짝반짝해져요.") }
        if morning >= 0.35 { return Personality(title: "아침형", habit: "아침 햇살에 기지개를 쭉 켜요.") }
        if averageBonus >= 7 { return Personality(title: "감성파", habit: "멋진 장면을 보면 감탄을 잘해요.") }
        return Personality(title: "느긋한 산책러", habit: "느릿느릿 둥실둥실 떠다니는 걸 좋아해요.")
    }
}

/// 애착 사진: the one photo the friend keeps. The user can choose it; otherwise the friend picks the brightest moment.
enum Keepsake {
    static func photo(in photos: [PhotoRecord], chosen id: String) -> PhotoRecord? {
        if let chosen = photos.first(where: { $0.id.uuidString == id }) { return chosen }
        // highest light/detail bonus; on a tie, the earlier memory
        return photos.max { lhs, rhs in lhs.bonus == rhs.bonus ? lhs.date > rhs.date : lhs.bonus < rhs.bonus }
    }
}
