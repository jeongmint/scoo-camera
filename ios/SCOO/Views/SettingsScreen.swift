import SwiftUI
import AuthenticationServices
import UIKit

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dateStamp") private var dateStamp = true
    @AppStorage("autoSave") private var autoSave = false
    @AppStorage("assignedCompanion") private var assignedRaw = ""
    @AppStorage("district") private var districtRaw = ""
    @AppStorage("unlockAllFriends") private var unlockAll = false
    @AppStorage("savePlace") private var savePlace = true
    @AppStorage("bottleFastMode") private var bottleFast = false
    @AppStorage("bottleOnline") private var bottleOnline = true
    @AppStorage("talkOnline") private var talkOnline = true
    @AppStorage("localAlerts") private var localAlerts = true
    @AppStorage("shareMoments") private var shareMoments = true
    @State private var accountID: String?
    @State private var connecting = false
    @State private var nickname = ""
    @State private var anonymous = true
    @State private var email: String?
    @State private var provider: String?
    @State private var webLogin: OAuthProvider?
    @State private var loginNote: String?
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var appleNonce = ""
    @StateObject private var social = SocialStore()
    @StateObject private var locator = DistrictLocator()
    @State private var finding = false
    @State private var note: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("날짜 인쇄", isOn: $dateStamp)
                    Toggle("사진 앱에도 자동 저장", isOn: $autoSave)
                    Toggle("찍은 자리를 지도에 남기기", isOn: $savePlace)
                } header: { Text("카메라") } footer: { Text("앱 앨범에는 항상 저장해요. 자동 저장을 켜면 다음 촬영 후 사진 추가 권한을 요청해요.") }
                Section {
                    LabeledContent("지금 동네", value: districtRaw.isEmpty ? "정해지지 않음" : districtRaw)
                    LabeledContent("내 친구", value: Companion(rawValue: assignedRaw)?.title ?? "아직 없음")
                    Button(finding ? "위치 확인 중…" : "내 위치로 다시 찾기") { Task { await findByLocation() } }.disabled(finding)
                    Menu("구를 직접 골라서 받기") {
                        ForEach(SeoulDistrict.allCases) { district in
                            Button("\(district.rawValue) · \(district.primary.title)") { receive(in: district) }
                        }
                    }
                    Button("랜덤으로 다시 받기") { receiveRandom() }
                    Toggle("모든 친구 열기 (교배 테스트)", isOn: $unlockAll)
                    Toggle("유리병 빠르게 (1분 배송 테스트)", isOn: $bottleFast)
                    if let note { Text(note).font(.footnote) }
                } header: { Text("동네 친구 (테스트)") } footer: {
                    Text("서울 25개 구마다 잘 만나는 친구가 달라요. 구의 친구가 70%, 나머지는 다른 친구예요. 새로 받아도 사진과 성장 기록은 그대로예요. ‘모든 친구 열기’를 켜면 교배 화면에서 25종을 모두 고를 수 있어요.")
                }
                Section {
                    if SupabaseConfig.isConfigured {
                        LabeledContent("계정", value: accountLabel)
                        if let loginNote { Text(loginNote).font(.footnote).foregroundStyle(Palette.moss) }
                        if accountID != nil && anonymous {
                            if SupabaseConfig.appleSignInAvailable {
                                SignInWithAppleButton(.continue) { request in
                                    appleNonce = AppleNonce.make()
                                    request.requestedScopes = [.email]
                                    request.nonce = AppleNonce.sha256(appleNonce)
                                } onCompletion: { result in
                                    Task { await finishApple(result) }
                                }
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 44)
                            }
                            ForEach(OAuthProvider.allCases) { option in
                                Button { Task { await finishWeb(option) } } label: {
                                    Text(webLogin == option ? "\(option.title) 로그인 중…" : "\(option.title)로 계속하기")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(option == .kakao ? Color.black.opacity(0.85) : Color.black)
                                        .background(option == .kakao ? Color(red: 1, green: 0.898, blue: 0) : Color.white,
                                                    in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(option == .google ? 0.2 : 0)))
                                }
                                .buttonStyle(.plain)
                                .disabled(webLogin != nil)
                            }
                            Text("\(loginNames) 중 하나로 이어 두면 앱을 지우거나 폰을 바꿔도 친구·유리병·편지가 그대로 남아요.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if accountID == nil {
                            Button(connecting ? "연결 중…" : "서버에 연결하기") { Task { await connect() } }.disabled(connecting)
                        }
                        Toggle("유리병을 진짜 사람들과 주고받기", isOn: $bottleOnline)
                        Toggle("입양한 아기 편지에 사진 주제 보내기", isOn: $shareMoments)
                        if accountID != nil {
                            HStack {
                                TextField(social.profile?.nickname ?? "친구에게 보일 이름", text: $nickname)
                                Button("저장") {
                                    Task {
                                        do { try await social.setNickname(nickname); nickname = ""; note = "이름을 바꿨어요." }
                                        catch { note = error.localizedDescription }
                                    }
                                }
                                .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            if let code = social.profile?.friend_code {
                                LabeledContent("내 친구 코드", value: code)
                            }
                            Button(deleting ? "지우는 중…" : "계정 삭제", role: .destructive) { confirmDelete = true }
                                .disabled(deleting)
                                .confirmationDialog("계정을 지울까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                                    Button("계정과 서버 기록 지우기", role: .destructive) { Task { await deleteAccount() } }
                                    Button("취소", role: .cancel) { }
                                } message: {
                                    Text("친구·편지·유리병 기록이 서버에서 바로 지워지고 되돌릴 수 없어요. 이미 다른 사람에게 도착한 아기는 그 사람에게 남아요. 이 iPhone의 사진은 그대로예요.")
                                }
                        }
                    } else {
                        Text("서버 키가 아직 없어서 유리병은 이 기기 안에서만 시험해요.").font(.footnote)
                    }
                } header: { Text("계정 · 서버") } footer: {
                    Text("로그인 없이 익명 계정으로 시작해요. \(loginNames)로 이어 두면 계정이 지켜져요. 계정 정보는 이 iPhone의 키체인에 보관돼요. 끄면 유리병은 기기 안의 가짜 바다로 돌아가요. 입양한 아기가 처음 가족에게 편지를 쓸 때, 내가 찍은 사진의 주제 단어(하늘·고양이·꽃 같은 정해진 단어)만 들어가요. 사진은 보내지 않아요.")
                }
                .task { await refreshAccount() }
                Section {
                    Toggle("유리병·편지 알림", isOn: $localAlerts)
                        .onChange(of: localAlerts) { _, on in Task { await updateAlerts(on) } }
                } header: { Text("알림") } footer: {
                    Text("유리병이 도착할 때와 보낸 아기가 편지를 쓸 때 알려 줘요. 이 iPhone이 스스로 맞춰 두는 알림이라 서버를 거치지 않아요. 새 친구 편지·친구 요청 알림은 다음 업데이트에서 와요.")
                }
                Section {
                    Toggle("AI로 대답하기", isOn: $talkOnline)
                    LabeledContent("이 iPhone의 대답", value: OnDeviceReplies.isAvailable ? "기기 안 AI (무료)" : (talkOnline ? "서버 AI" : "앱 안 대답"))
                } header: { Text("대화 모드") } footer: {
                    Text("카메라 위쪽 말풍선을 누르면 떠 있는 친구와 목소리로 이야기해요. 목소리는 iPhone에서 글자로 바뀌고, 녹음은 남기지 않아요. Apple Intelligence가 되는 iPhone은 기기 안 AI가 대답해서 아무것도 밖으로 나가지 않아요. 그 밖의 iPhone에서 ‘AI로 대답하기’를 켜면 그 글자만 서버를 거쳐 AI로 보내 대답을 만들고, 대화 내용은 저장하지 않아요. 끄면 앱 안의 간단한 대답만 해요.")
                }
                Section("Eternal") {
                    Text("차가운 회색 그림자와 따뜻한 빛, 짙은 검정과 작은 디지털 입자. 필터는 Eternal 하나만 사용해요.").font(.footnote)
                }
                Section("작은 친구") {
                    Text("카메라 위의 모리를 짧게 누르면 촬영해요. 0.35초 동안 꾹 누른 뒤 끌면 위치를 옮길 수 있어요. 화면 왼쪽 위 이름을 누르면 성장 기록이 열려요.")
                    Text("처음 켤 때 있는 서울 구에 따라 귀요·쿠르·모리·냐모 중 한 명이 찾아와요. 사람마다 한 명씩이고, 위치를 쓸 수 없으면 랜덤이에요. 테스트 버전에서는 이벤트 친구 해피(눈사람)도 함께 와요.")
                    Text("촬영 모드 메뉴의 ‘떠 있는 친구’에서 내 친구를 고르면 모리 대신 그 친구가 떠 있어요. ‘사진에 같이 찍기’를 켜면 떠 있던 자리 그대로 사진에도 함께 찍히고, 끄면 화면에만 떠 있어요. ‘기본 모리’를 고르면 다시 모리가 돌아와요.")
                    Text("찍는 순간 모리는 눈을 감고, 사진이 저장되면 표정으로 반응해요. 음식은 냠냠, 빛과 디테일이 좋으면 감탄, 레벨이 오르면 방긋, 그 밖에는 방긋이나 깜짝이에요.")
                    Text("자동 모드는 Apple Vision을 이용해 기기 안에서 음식 여부를 추정해요. 잘못 분류되면 촬영 전 음식 또는 일상 모드를 직접 골라 주세요.")
                    Text("사진 보너스는 빛과 픽셀의 변화를 계산해요. 미적 감동이나 사진의 예술성을 평가하는 AI는 아직 연결하지 않았어요.")
                }.font(.footnote)
                Section("내 사진, 내 기기에") {
                    Text("사진과 마리모 기록은 이 iPhone의 앱 보관함에 저장돼요. 사진은 서버로 보내지 않고, 광고·분석 SDK가 없어요. 서버에는 유리병·친구·편지, 입양한 아기 편지용 사진 주제 단어, 대화 모드의 글자(켰을 때)만 오가요. 동네 친구를 찾을 때 구 이름은 Apple 지도 서비스에서 받아와요. ‘찍은 자리를 지도에 남기기’를 켜면 사진마다 찍은 위치가 이 iPhone 안에만 저장돼 지도 방명록에 보여요. 앱을 삭제하면 보관함도 사라져요. 중요한 사진은 사진 앱에 저장해 주세요.").font(.footnote)
                    NavigationLink("개인정보 처리방침") { PrivacyScreen() }
                    Button("iPhone 설정 열기") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                }
                Section { HStack { Text("SCOO").font(.headline); Spacer(); Text("0.2 · Eternal").font(.caption2).foregroundStyle(.secondary) } }
            }.scrollContentBackground(.hidden).background(Palette.cream).tint(Palette.moss)
                .navigationTitle("작은 설정").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
        }
    }

    private func deleteAccount() async {
        deleting = true
        defer { deleting = false }
        do {
            try await SupabaseClient.shared.deleteAccount()
            await LocalNotifier.cancelAll()
            loginNote = "계정을 지웠어요. 다시 서버에 연결하면 새 익명 계정으로 시작해요."
        } catch {
            loginNote = error.localizedDescription
        }
        await refreshAccount()
    }

    private func updateAlerts(_ on: Bool) async {
        guard on else { await LocalNotifier.cancelAll(); return }
        await LocalNotifier.askIfNeeded()
        let bottles = BottleStore.preferred()
        if !bottles.isOnline || accountID != nil { await bottles.load() }
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

    /// Apple only shows up in builds signed by a paid team.
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

    private func receive(in district: SeoulDistrict) {
        var generator = SystemRandomNumberGenerator()
        let friend = Companion.assign(in: district, using: &generator)
        districtRaw = district.rawValue
        assignedRaw = friend.rawValue
        note = "\(district.rawValue) · \(friend.title)"
    }

    private func receiveRandom() {
        var generator = SystemRandomNumberGenerator()
        let friend = Companion.assign(using: &generator)
        districtRaw = ""
        assignedRaw = friend.rawValue
        note = "랜덤 · \(friend.title)"
    }

    private func findByLocation() async {
        finding = true
        defer { finding = false }
        switch await locator.currentDistrict() {
        case .success(let district): receive(in: district)
        case .failure(let failure): note = failure.reason
        }
    }
}
