import Foundation
import ActivityKit

/// 산책 모드: a Live Activity on the lock screen and Dynamic Island while the user is out taking photos.
/// Shared by the app (starts and updates it) and the widget extension (draws it).
struct WalkAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Photos taken since the walk started.
        var photos: Int
        /// The Seoul district the walk is in, once known.
        var district: String?
    }

    var heroName: String
    var startedAt: Date
}
