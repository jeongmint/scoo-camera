import Foundation
import ActivityKit

/// Starts, updates and ends the 산책 모드 Live Activity.
@MainActor
enum WalkMode {
    private static var current: Activity<WalkAttributes>? { Activity<WalkAttributes>.activities.first }

    static var isActive: Bool { current != nil }
    static var isAllowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    static var startedAt: Date? { current?.attributes.startedAt }

    static func start(heroName: String, district: String?) throws {
        guard current == nil else { return }
        guard isAllowed else { throw SCOOError.message("설정 > SCOO에서 ‘실시간 현황’을 켜 주세요.") }
        let attributes = WalkAttributes(heroName: heroName, startedAt: Date())
        let state = WalkAttributes.ContentState(photos: 0, district: district)
        _ = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil)
    }

    /// Changes only what is given; the rest stays as it is.
    static func update(photos: Int? = nil, district: String? = nil) {
        guard let activity = current else { return }
        let old = activity.content.state
        let state = WalkAttributes.ContentState(photos: photos ?? old.photos, district: district ?? old.district)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    static func end() {
        guard let activity = current else { return }
        Task { await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate) }
    }
}
