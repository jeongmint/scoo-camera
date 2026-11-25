import Foundation

/// 신고 처리 for operators: reported letters, and what to do with each (see supabase report_review migration).
/// The server checks that the account is an operator for every call.
@MainActor
final class ReportDesk: ObservableObject {
    struct Report: Decodable, Identifiable, Equatable {
        let id: Int64
        let created_at: Date
        let reason: String?
        let status: String
        let action_note: String?
        let reviewed_at: Date?
        let reporter_name: String?
        let reported: UUID?
        let reported_name: String?
        let reported_total: Int
        let suspended_until: Date?
        let message_id: UUID?
        let body: String?
        let sticker: String?
        let photo: String?
        let letter_exists: Bool

        var statusTitle: String {
            switch status {
            case "dismissed": return "문제 없음"
            case "removed": return "편지 지움"
            case "suspended": return "편지 지우고 보내기 정지"
            default: return "처리 전"
            }
        }

        /// Whether the reported person cannot send letters right now.
        func isSuspended(at now: Date = Date()) -> Bool { suspended_until.map { $0 > now } ?? false }
    }

    enum Action: String, CaseIterable {
        case dismiss, remove, suspend

        var title: String {
            switch self {
            case .dismiss: return "문제 없음"
            case .remove: return "편지 지우기"
            case .suspend: return "지우고 7일 정지"
            }
        }

        var explanation: String {
            switch self {
            case .dismiss: return "편지는 그대로 두고 신고만 닫아요."
            case .remove: return "받은 사람 편지함에서 이 편지를 지워요. 사진도 더는 열리지 않아요."
            case .suspend: return "편지를 지우고, 보낸 사람이 7일 동안 편지와 친구 요청을 보낼 수 없게 해요."
            }
        }
    }

    @Published private(set) var reports: [Report] = []
    @Published private(set) var loading = false
    @Published var message: String?
    private var photos: [String: Data] = [:]
    private let client: SupabaseClient

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    /// Open reports, or the ones already handled.
    func load(open: Bool) async {
        loading = true
        defer { loading = false }
        do { reports = try await client.rpc("review_reports", ["p_open": open], as: [Report].self) }
        catch { message = error.localizedDescription }
    }

    /// Handles one report; then the list is read again (`open` says which list is showing).
    func resolve(_ report: Report, _ action: Action, note: String, open: Bool) async {
        do {
            _ = try await client.rpc("resolve_report", ["p_id": report.id, "p_action": action.rawValue, "p_note": note, "p_days": 7],
                                     as: Bool.self)
        } catch { message = error.localizedDescription }
        await load(open: open)
    }

    func lift(_ report: Report, open: Bool) async {
        guard let user = report.reported else { return }
        do { try await client.call(rpc: "lift_suspension", ["p_user": user.uuidString]) }
        catch { message = error.localizedDescription }
        await load(open: open)
    }

    /// The reported letter's photo (operators may read reported photos).
    func photo(_ path: String) async -> Data? {
        if let cached = photos[path] { return cached }
        guard let data = try? await client.download(bucket: "letters", path: path) else { return nil }
        photos[path] = data
        return data
    }
}
