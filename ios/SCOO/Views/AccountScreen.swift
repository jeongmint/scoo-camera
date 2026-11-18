import SwiftUI
import AuthenticationServices

/// The login page: the anonymous account and linking it to Apple·Google·카카오, split out of 작은 설정.
struct AccountScreen: View {
    @State private var accountID: String?
    @State private var anonymous = true
    @State private var email: String?
    @State private var provider: String?
    @State private var connecting = false
    @State private var webLogin: OAuthProvider?
    @State private var loginNote: String?
    @State private var appleNonce = ""
    @State private var nickname = ""
    @State private var note: String?
    @StateObject private var social = SocialStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if !SupabaseConfig.isConfigured {
                    Text("서버 키가 아직 없어서 유리병은 이 기기 안에서만 시험해요.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if accountID == nil {
                    Button { Task { await connect() } } label: {
                        Text(connecting ? "연결 중…" : "익명으로 시작하기").loginLabel(fill: Palette.moss, text: .white)
                    }
                    .buttonStyle(.plain).disabled(connecting)
                } else if anonymous {
                    loginButtons
                } else {
                    profileCard
                }
                if let loginNote { Text(loginNote).font(.footnote).foregroundStyle(Palette.moss).multilineTextAlignment(.center) }
                if let note { Text(note).font(.footnote).foregroundStyle(.secondary) }
                Text("계정 정보는 이 iPhone의 키체인에 보관돼요. 사진은 서버로 보내지 않아요.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .background(Palette.cream.ignoresSafeArea())
        .navigationTitle("계정").navigationBarTitleDisplayMode(.inline)
        .task { await refreshAccount() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image("Companion-mori").resizable().scaledToFit().frame(width: 96, height: 96)
            Text(anonymous ? "친구들을 잃어버리지 않게" : "계정이 지켜지고 있어요")
                .font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
            Text(accountLabel).font(.footnote).foregroundStyle(.secondary)
            if anonymous && accountID != nil {
                Text("\(loginNames) 중 하나로 이어 두면 앱을 지우거나 폰을 바꿔도 친구·유리병·편지가 그대로 남아요.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(.top, 12)
    }

    private var loginButtons: some View {
        VStack(spacing: 12) {
            if SupabaseConfig.appleSignInAvailable {
                SignInWithAppleButton(.continue) { request in
                    appleNonce = AppleNonce.make()
                    request.requestedScopes = [.email]
                    request.nonce = AppleNonce.sha256(appleNonce)
                } onCompletion: { result in
                    Task { await finishApple(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            ForEach(OAuthProvider.allCases) { option in
                Button { Task { await finishWeb(option) } } label: {
                    Text(webLogin == option ? "\(option.title) 로그인 중…" : "\(option.title)로 계속하기")
                        .loginLabel(fill: option == .kakao ? Color(red: 1, green: 0.898, blue: 0) : .white,
                                    text: Color.black.opacity(option == .kakao ? 0.85 : 1),
                                    stroke: option == .google)
                }
                .buttonStyle(.plain).disabled(webLogin != nil)
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField(social.profile?.nickname ?? "친구에게 보일 이름", text: $nickname).textFieldStyle(.roundedBorder)
                Button("저장") {
                    Task {
                        do { try await social.setNickname(nickname); nickname = ""; note = "이름을 바꿨어요." }
                        catch { note = error.localizedDescription }
                    }
                }
                .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let code = social.profile?.friend_code { LabeledContent("내 친구 코드", value: code) }
        }
        .padding(16)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    private var loginNames: String {
        SupabaseConfig.appleSignInAvailable ? "Apple·Google·카카오" : "Google·카카오"
    }

    private var accountLabel: String {
        guard let id = accountID else { return "아직 연결 안 됨" }
        if anonymous { return "익명 · \(id.prefix(8))" }
        let names = ["apple": "Apple", "google": "Google", "kakao": "카카오"]
        let name = provider.flatMap { names[$0] } ?? "로그인"
        return "\(name) · \(email ?? String(id.prefix(8)))"
    }

    private func connect() async {
        connecting = true
        defer { connecting = false }
        do { _ = try await SupabaseClient.shared.signIn() }
        catch { note = error.localizedDescription }
        await refreshAccount()
    }

    private func refreshAccount() async {
        let client = SupabaseClient.shared
        accountID = await client.currentUserID
        anonymous = await client.isAnonymous
        email = await client.email
        provider = await client.provider
        if accountID != nil { await social.refresh() }
    }

    private func finishWeb(_ option: OAuthProvider) async {
        webLogin = option
        loginNote = nil
        defer { webLogin = nil }
        do {
            switch try await SupabaseClient.shared.signIn(with: option, browser: { try await WebLogin.open($0) }) {
            case .linked: loginNote = "\(option.title) 계정과 이어졌어요. 이제 앱을 지워도 그대로 남아요."
            case .switched: loginNote = "이 \(option.title) 계정에 있던 기존 계정으로 돌아왔어요."
            }
        } catch is WebLogin.Cancelled {
        } catch {
            loginNote = error.localizedDescription
        }
        await refreshAccount()
    }

    private func finishApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { loginNote = error.localizedDescription }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
                loginNote = "Apple에서 로그인 정보를 받지 못했어요."
                return
            }
            do {
                switch try await SupabaseClient.shared.signInWithApple(idToken: token, nonce: appleNonce) {
                case .linked: loginNote = "Apple 계정과 이어졌어요. 이제 앱을 지워도 그대로 남아요."
                case .switched: loginNote = "이 Apple 계정에 있던 기존 계정으로 돌아왔어요."
                }
            } catch {
                loginNote = error.localizedDescription
            }
            await refreshAccount()
        }
    }
}

private extension Text {
    func loginLabel(fill: Color, text: Color, stroke: Bool = false) -> some View {
        font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(text)
            .background(fill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(stroke ? 0.2 : 0)))
    }
}
