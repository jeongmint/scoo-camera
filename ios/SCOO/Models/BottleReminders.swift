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

    /// `real`: with real people only the first letter is sure to come (later ones need a shared word), so only
    /// that one is announced ahead; the rest show up in the app when they do come.
    static func plan(_ bottles: [Bottle], now: Date, fast: Bool, real: Bool = false) -> [Reminder] {
        var reminders: [Reminder] = []
        for bottle in bottles {
            switch bottle.direction {
            case .incoming where !bottle.opened && bottle.arrivesAt > now:
                reminders.append(Reminder(id: "\(prefix)arrive-\(bottle.id)", date: bottle.arrivesAt,
                                          title: "유리병이 도착했어요",
                                          body: "\(bottle.origin)에서 \(bottle.title) 아기가 떠내려왔어요. 열어 볼까요?"))
            case .outgoing where bottle.isWaitingAtSea && bottle.settled != true:
                // nobody came yet: the next day the sea brings a new character (unless someone swaps first)
                let due = bottle.sentAt.addingTimeInterval(BottleRules.travelTime(fast: fast))
                if due > now {
                    reminders.append(Reminder(id: "\(prefix)sea-\(bottle.id)", date: due, title: "유리병의 답이 왔어요",
                                              body: "바다에서 새 친구가 떠내려왔을지도 몰라요. 열어 볼까요?"))
                }
            case .outgoing where bottle.wantsNews && !bottle.isWaitingAtSea:
                for index in 0..<(real ? 1 : BottleRules.maxLetters) {
                    let date = BottleRules.letterDate(bottle, index: index, fast: fast)
                    guard date > now else { continue }
                    reminders.append(Reminder(id: "\(prefix)letter-\(bottle.id)-\(index)", date: date,
                                              title: "\(bottle.title)에게서 편지가 왔어요",
                                              // The words arrive with the new family's photos, so the
                                              // letter itself is read in the app.
                                              body: "새 가족이랑 지낸 이야기가 담겨 있어요. 열어 볼까요?"))
                }
            default:
                break
            }
        }
        return Array(reminders.sorted { $0.date < $1.date }.prefix(limit))
    }
}
