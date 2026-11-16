import Foundation

/// What the app shares with the widget through the app group. Compiled into both the app and the widget.
enum WidgetShared {
    /// Must match the App Groups capability of both targets (SCOO.entitlements, SCOOWidget.entitlements).
    static let appGroup = "group.com.jeongmint.scoo"
    static let snapshotKey = "widgetSnapshot"
    static let pettedKey = "widgetPettedAt"
    /// How long the widget stays happy after being petted.
    static let happySeconds: TimeInterval = 8

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }
    static var container: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) }

    /// Small PNGs the app renders for the widget ("hero" = the floating character, "friend", "baby").
    static func imageURL(_ name: String) -> URL? { container?.appendingPathComponent("widget-\(name).png") }
}

/// Everything the widget shows, written by the app whenever the garden, the friend or a baby changes.
struct WidgetSnapshot: Codable, Equatable {
    struct Baby: Codable, Equatable {
        var title: String
        var photosLeft: Int
        var adult: Bool
    }

    var name: String
    var level: Int
    /// EXP inside the current level, 0...99.
    var progress: Int
    var moments: Int
    var todayCount: Int
    /// The day `todayCount` belongs to.
    var today: Date
    var friendName: String?
    var baby: Baby?
    var updated: Date

    /// Photos taken on the day of `date`; zero once the day has turned over.
    func photosToday(at date: Date, calendar: Calendar = .current) -> Int {
        calendar.isDate(today, inSameDayAs: date) ? todayCount : 0
    }

    static let placeholder = WidgetSnapshot(name: "모리", level: 1, progress: 30, moments: 0, todayCount: 0,
                                            today: Date(), friendName: nil, baby: nil, updated: Date())

    static func load(from defaults: UserDefaults? = WidgetShared.defaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: WidgetShared.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save(to defaults: UserDefaults? = WidgetShared.defaults) {
        guard let defaults, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: WidgetShared.snapshotKey)
    }
}
