import Foundation

/// A notification the phone schedules for itself (no server, works with a free developer account).
struct Reminder: Equatable {
    /// Stable per event, so rescheduling replaces instead of doubling.
    let id: String
    let date: Date
    let title: String
    let body: String
}

/// What to tell the user about bottles, and when: an incoming bottle washing up, and each letter from a baby
/// that was sent away with "가끔 소식 전해줘".
enum BottleReminders {
    static let prefix = "bottle-"
    /// iOS keeps at most 64 pending notifications per app; leave room for others.
    static let limit = 48

    static func plan(_ bottles: [Bottle], now: Date, fast: Bool) -> [Reminder] {
        var reminders: [Reminder] = []
        for bottle in bottles {
            switch bottle.direction {
            case .incoming where !bottle.opened && bottle.arrivesAt > now:
                reminders.append(Reminder(id: "\(prefix)arrive-\(bottle.id)", date: bottle.arrivesAt,
                                          title: "유리병이 도착했어요",
                                          body: "\(bottle.origin)에서 \(bottle.title) 아기가 떠내려왔어요. 열어 볼까요?"))
            case .outgoing where bottle.wantsNews:
                for index in 0..<BottleRules.maxLetters {
                    let date = BottleRules.letterDate(bottle, index: index, fast: fast)
                    guard date > now else { continue }
                    reminders.append(Reminder(id: "\(prefix)letter-\(bottle.id)-\(index)", date: date,
                                              title: "\(bottle.title)에게서 편지가 왔어요",
                                              body: BottleRules.letterText(bottle, index: index)))
                }
            default:
                break
            }
        }
        return Array(reminders.sorted { $0.date < $1.date }.prefix(limit))
    }
}
