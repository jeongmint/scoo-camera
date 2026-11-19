import SwiftUI
import UIKit

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dateStamp") private var dateStamp = true
    @AppStorage("autoSave") private var autoSave = false
    @AppStorage("assignedCompanion") private var assignedRaw = ""
    @ObservedObject private var friends = FriendStore.shared
    @AppStorage("district") private var districtRaw = ""
    @AppStorage("unlockAllFriends") private var unlockAll = false
    @AppStorage("savePlace") private var savePlace = true
    @AppStorage("bottleFastMode") private var bottleFast = false
    @AppStorage("bottleOnline") private var bottleOnline = true
    @AppStorage("talkOnline") private var talkOnline = true
    @AppStorage("localAlerts") private var localAlerts = true
    @AppStorage("shareMoments") private var shareMoments = true
    @State private var accountID: String?
    @State private var anonymous = true
    @State private var email: String?
    @State private var provider: String?
    @StateObject private var locator = DistrictLocator()
    @State private var finding = false
    @State private var note: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { AccountScreen() } label: {
                        HStack(spacing: 14) {
                            Image(friends.starter?.character?.assetName ?? "Companion-mori")
                                .resizable().scaledToFit().frame(width: 52, height: 52)
                                .background(Glass.row, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(anonymous ? "계정 이어 두기" : "내 계정").font(.headline)
                                Text(accountLabel).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }.listRowBackground(Glass.row)
                .task { await refreshAccount() }
                Section {
                    row("카메라", icon: "camera.fill", color: Palette.moss, value: dateStamp ? "날짜 인쇄" : "") { cameraPage }
                    if SupabaseConfig.isConfigured {
                        row("유리병 · 편지", icon: "envelope.fill", color: .blue, value: bottleOnline ? "진짜 사람들" : "가짜 바다") { bottlePage }
                    }
                    row("대화", icon: "bubble.left.fill", color: .orange, value: replyLabel) { talkPage }
                    row("알림", icon: "bell.fill", color: .red, value: localAlerts ? "켬" : "끔") { alertsPage }
                }.listRowBackground(Glass.row)
                Section {
                    row("SCOO 안내", icon: "book.fill", color: .gray) { guide }
                    row("개인정보 처리방침", icon: "lock.fill", color: .gray) { PrivacyScreen() }
                    Button("iPhone 설정 열기") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                }.listRowBackground(Glass.row)
                Section {
                    row("테스트 도구", icon: "testtube.2", color: Color(white: 0.7)) { testTools }
                }.listRowBackground(Glass.row)
                Section { HStack { Text("SCOO").font(.headline); Spacer(); Text("0.2 · Eternal").font(.caption2).foregroundStyle(.secondary) } }.listRowBackground(Color.clear)
            }.glassSheet()
                .navigationTitle("작은 설정").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
        }
    }

    private func row<Destination: View>(_ title: String, icon: String, color: Color, value: String = "",
                                        @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(color, in: RoundedRectangle(cornerRadius: 8))
                Text(title)
                Spacer()
                Text(value).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var replyLabel: String {
        OnDeviceReplies.isAvailable ? "기기 안 AI" : (talkOnline ? "서버 AI" : "앱 안 대답")
    }

    private func page<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Form { content() }
            .glassSheet()
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }

    private var cameraPage: some View {
        page("카메라") {
            Section {
                Toggle("날짜 인쇄", isOn: $dateStamp)
            } footer: { Text("사진 오른쪽 아래에 찍은 날짜를 새겨요.") }.listRowBackground(Glass.row)
            Section {
                Toggle("사진 앱에도 자동 저장", isOn: $autoSave)
            } footer: { Text("앱 앨범에는 항상 저장해요. 켜면 다음 촬영 후 사진 추가 권한을 물어봐요.") }.listRowBackground(Glass.row)
            Section {
                Toggle("찍은 자리를 지도에 남기기", isOn: $savePlace)
            } footer: { Text("위치는 이 iPhone 안에만 저장돼 지도 방명록에 보여요.") }.listRowBackground(Glass.row)
        }
    }

    private var bottlePage: some View {
        page("유리병 · 편지") {
            Section {
                Toggle("진짜 사람들과 주고받기", isOn: $bottleOnline)
            } footer: { Text("끄면 유리병은 이 iPhone 안의 가짜 바다로 돌아가요.") }.listRowBackground(Glass.row)
            Section {
                Toggle("아기 편지에 사진 주제 넣기", isOn: $shareMoments)
            } footer: { Text("입양한 아기가 처음 편지를 쓸 때 ‘하늘·고양이·꽃’ 같은 정해진 단어만 들어가요. 사진은 보내지 않아요.") }.listRowBackground(Glass.row)
        }
    }

    private var talkPage: some View {
        page("대화") {
            Section {
                LabeledContent("이 iPhone의 대답", value: OnDeviceReplies.isAvailable ? "기기 안 AI (무료)" : replyLabel)
                Toggle("AI로 대답하기", isOn: $talkOnline)
            } footer: {
                Text("카메라 위 말풍선을 누르면 떠 있는 친구와 목소리로 이야기해요. 녹음은 남기지 않아요. 기기 안 AI가 없는 iPhone에서 켜면 말한 글자만 서버 AI로 보내고, 대화 내용은 저장하지 않아요.")
            }.listRowBackground(Glass.row)
        }
    }

    private var alertsPage: some View {
        page("알림") {
            Section {
                Toggle("유리병·편지 알림", isOn: $localAlerts)
                    .onChange(of: localAlerts) { _, on in Task { await updateAlerts(on) } }
            } footer: { Text("유리병이 도착할 때와 보낸 아기가 편지를 쓸 때 알려 줘요. 이 iPhone이 스스로 맞춰 두는 알림이에요.") }.listRowBackground(Glass.row)
        }
    }

    private var guide: some View {
        Form {
                Section("대화 모드") {
                    Text("카메라 위쪽 말풍선을 누르면 떠 있는 친구와 목소리로 이야기해요. 목소리는 iPhone에서 글자로 바뀌고, 녹음은 남기지 않아요. ‘AI로 대화하기’를 켜면 Apple Intelligence가 되는 iPhone은 기기 안 AI가 대답해서 아무것도 밖으로 나가지 않아요. 그 밖의 iPhone에서는 그 글자만 서버를 거쳐 AI로 보내 대답을 만들고, 대화 내용은 저장하지 않아요. 끄면 앱 안의 간단한 대답만 해요.")
                    Text("유리병·편지 알림은 이 iPhone이 스스로 맞춰 두는 알림이라 서버를 거치지 않아요.")
                    Text("유리병을 끄면 기기 안의 가짜 바다로 돌아가요. 입양한 아기가 처음 가족에게 편지를 쓸 때, 내가 찍은 사진의 주제 단어(하늘·고양이·꽃 같은 정해진 단어)만 들어가요.")
                }.listRowBackground(Glass.row).font(.footnote)
                Section("Eternal") {
                    Text("차가운 회색 그림자와 따뜻한 빛, 짙은 검정과 작은 디지털 입자. 필터는 Eternal 하나만 사용해요.").font(.footnote)
                }.listRowBackground(Glass.row)
                Section("작은 친구") {
                    Text("카메라 위의 모리를 짧게 누르면 촬영해요. 0.35초 동안 꾹 누른 뒤 끌면 위치를 옮길 수 있어요. 화면 왼쪽 위 이름을 누르면 성장 기록이 열려요.")
                    Text("처음 켤 때 있는 서울 구에 따라 귀요·쿠르·모리·냐모 중 한 명이 찾아와요. 사람마다 한 명씩이고, 위치를 쓸 수 없으면 랜덤이에요. 테스트 버전에서는 이벤트 친구 해피(눈사람)도 함께 와요.")
                    Text("촬영 모드 메뉴의 ‘떠 있는 친구’에서 내 친구를 고르면 모리 대신 그 친구가 떠 있어요. ‘사진에 같이 찍기’를 켜면 떠 있던 자리 그대로 사진에도 함께 찍히고, 끄면 화면에만 떠 있어요. ‘기본 모리’를 고르면 다시 모리가 돌아와요.")
                    Text("찍는 순간 모리는 눈을 감고, 사진이 저장되면 표정으로 반응해요. 음식은 냠냠, 빛과 디테일이 좋으면 감탄, 레벨이 오르면 방긋, 그 밖에는 방긋이나 깜짝이에요.")
                    Text("자동 모드는 Apple Vision을 이용해 기기 안에서 음식 여부를 추정해요. 잘못 분류되면 촬영 전 음식 또는 일상 모드를 직접 골라 주세요.")
                    Text("사진 보너스는 빛과 픽셀의 변화를 계산해요. 미적 감동이나 사진의 예술성을 평가하는 AI는 아직 연결하지 않았어요.")
                }.listRowBackground(Glass.row).font(.footnote)
                Section("내 사진, 내 기기에") {
                    Text("사진과 마리모 기록은 이 iPhone의 앱 보관함에 저장돼요. 사진은 서버로 보내지 않고, 광고·분석 SDK가 없어요. 서버에는 유리병·친구·편지, 입양한 아기 편지용 사진 주제 단어, 대화 모드의 글자(켰을 때)만 오가요. 동네 친구를 찾을 때 구 이름은 Apple 지도 서비스에서 받아와요. ‘찍은 자리를 지도에 남기기’를 켜면 사진마다 찍은 위치가 이 iPhone 안에만 저장돼 지도 방명록에 보여요. 앱을 삭제하면 보관함도 사라져요. 중요한 사진은 사진 앱에 저장해 주세요.").font(.footnote)
                    Button("iPhone 설정 열기") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                }.listRowBackground(Glass.row)
        }
        .glassSheet()
        .navigationTitle("SCOO 안내").navigationBarTitleDisplayMode(.inline)
    }

    private var testTools: some View {
        Form {
                Section {
                    LabeledContent("지금 동네", value: Regions.resolve(districtRaw)?.title ?? (districtRaw.isEmpty ? "정해지지 않음" : districtRaw))
                    LabeledContent("첫 친구", value: friends.starter?.character?.name ?? "아직 없음")
                    LabeledContent("가진 친구", value: "\(friends.friends.count)마리")
                    Button(finding ? "위치 확인 중…" : "내 위치로 다시 찾기") { Task { await findByLocation() } }.disabled(finding)
                    Menu("동네를 직접 골라서 받기") {
                        ForEach(Province.allCases) { province in
                            Menu(province.rawValue) {
                                ForEach(Regions.of(province)) { region in
                                    Button("\(region.name) · \(region.candidateSpecies.map(\.name).joined(separator: "·"))") { receive(in: region) }
                                }
                            }
                        }
                    }
                    Button("랜덤으로 다시 받기") { receiveRandom() }
                    Toggle("모든 친구 열기 (교배 테스트)", isOn: $unlockAll)
                    Toggle("유리병 빠르게 (1분 배송 테스트)", isOn: $bottleFast)
                    if let note { Text(note).font(.footnote) }
                } header: { Text("동네 친구") } footer: {
                    Text("처음엔 지금 있는 시군구의 다섯 친구 중 한 마리만 와요. 더 많은 친구는 하루 한 번 유리병 입양으로 만나요. 다시 받으면 첫 친구만 바뀌고 사진과 성장 기록, 다른 친구는 그대로예요. ‘모든 친구 열기’를 켜면 교배 화면에서 25종을 모두 고를 수 있어요.")
                }.listRowBackground(Glass.row)
        }
        .glassSheet()
        .navigationTitle("테스트 도구").navigationBarTitleDisplayMode(.inline)
    }

    private func updateAlerts(_ on: Bool) async {
        guard on else { await LocalNotifier.cancelAll(); return }
        await LocalNotifier.askIfNeeded()
        let bottles = BottleStore.preferred()
        if !bottles.isOnline || accountID != nil { await bottles.load() }
    }

    private func refreshAccount() async {
        let client = SupabaseClient.shared
        accountID = await client.currentUserID
        anonymous = await client.isAnonymous
        email = await client.email
        provider = await client.provider
    }

    private var accountLabel: String {
        guard let id = accountID else { return "아직 연결 안 됨" }
        if anonymous { return "익명 · \(id.prefix(8))" }
        let names = ["apple": "Apple", "google": "Google", "kakao": "카카오"]
        let name = provider.flatMap { names[$0] } ?? "로그인"
        return "\(name) · \(email ?? String(id.prefix(8)))"
    }

    /// Testing: draw the first friend again from a place's 5 (other friends stay).
    private func receive(in region: Region) {
        var generator = SystemRandomNumberGenerator()
        let friend = region.drawStarter(using: &generator)
        districtRaw = region.id
        assignedRaw = friend.id
        friends.setStarter(friend, origin: region.title)
        note = "\(region.title)의 다섯 친구 중 \(friend.name)"
    }

    private func receiveRandom() {
        var generator = SystemRandomNumberGenerator()
        let friend = Regions.randomStarter(using: &generator)
        districtRaw = ""
        assignedRaw = friend.id
        friends.setStarter(friend, origin: nil)
        note = "랜덤 · \(friend.name)"
    }

    private func findByLocation() async {
        finding = true
        defer { finding = false }
        switch await locator.currentRegion() {
        case .success(let region): receive(in: region)
        case .failure(let failure): note = failure.reason
        }
    }
}
