import Foundation

/// 운영자 모드: the test menu (모든 친구 열기, 1분 배송, 첫 친구 다시 받기) for operator accounts only.
/// The server decides (`am_i_operator`, profiles.is_tester), and also refuses fast delivery and extra bottles
/// to everyone else; the answer is kept here so the menu shows without waiting.
enum OperatorMode {
    static let key = "operatorMode"
    /// Settings the test menu switches on. Turned off again for anyone who is not an operator.
    static let testKeys = ["unlockAllFriends", "bottleFastMode"]

    static var isOn: Bool { UserDefaults.standard.bool(forKey: key) }

    /// Asks the server and keeps the answer. Without an account it is off; when the server cannot be reached
    /// the last answer stays.
    @discardableResult
    static func refresh(defaults: UserDefaults = .standard) async -> Bool {
        guard SupabaseConfig.isConfigured, await SupabaseClient.shared.currentUserID != nil else {
            apply(false, defaults: defaults)
            return false
        }
        guard let on = try? await SupabaseClient.shared.rpc("am_i_operator", [:], as: Bool.self) else {
            return defaults.bool(forKey: key)
        }
        apply(on, defaults: defaults)
        return on
    }

    static func apply(_ on: Bool, defaults: UserDefaults = .standard) {
        defaults.set(on, forKey: key)
        if !on { testKeys.forEach { defaults.set(false, forKey: $0) } }
    }
}
