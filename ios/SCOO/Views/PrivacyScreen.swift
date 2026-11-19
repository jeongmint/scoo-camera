import SwiftUI

/// 개인정보 처리방침, inside the app (also needed for the App Store listing).
struct PrivacyScreen: View {
    private struct Part: Identifiable {
        let title: String
        let lines: [String]
        var id: String { title }
    }

    private let parts: [Part] = [
        Part(title: "이 iPhone에만 남는 것", lines: [
            "찍은 사진·동영상과 성장 기록, 지도 방명록의 사진 위치는 이 iPhone의 앱 보관함에만 저장돼요. 서버로 보내지 않아요.",
            "사진이 음식인지, 하늘·고양이 같은 무엇이 찍혔는지는 iPhone 안에서 판단해요.",
            "대화 모드의 목소리는 녹음하지 않고 iPhone에서 글자로 바꿔요.",
        ]),
        Part(title: "서버에 저장하는 것", lines: [
            "계정: 익명 계정 번호, 이어 붙인 로그인(Google·카카오·Apple)과 그 이메일, 닉네임, 친구 코드, 친구에게 보일 캐릭터.",
            "유리병: 보낸 아기의 부모 캐릭터와 출신 구, 보낸 시각과 도착 시각. 상대가 누군지는 서로 보이지 않아요.",
            "입양한 아기 편지: 새 가족이 찍은 사진의 주제 단어(하늘·고양이 등 정해진 11개)만. 사진은 보내지 않아요.",
            "친구와 편지: 친구 관계, 친구에게 보낸 글·스티커·사진, 신고와 차단 기록.",
            "하루 사용 횟수(교배 그림, 대화 모드 대답). 대화 내용 자체는 저장하지 않아요.",
            "주변 친구 보기(켰을 때만): 100m 단위로 줄인 대략 위치를 친구에게만 보여 주고, 끄거나 30분이 지나면 지워져요.",
            "근처에서 친구 추가: 그 화면을 연 동안에만 근처 iPhone에 이름과 친구 코드를 보여 줘요. 서버를 거치지 않아요.",
        ]),
        Part(title: "밖으로 보내는 곳", lines: [
            "서버는 Supabase에서 운영해요.",
            "교배 그림은 부모 캐릭터 그림만 OpenAI에 보내 새로 그려요.",
            "대화 모드에서 기기 안 AI를 쓸 수 없는 iPhone은 말한 글자를 서버를 거쳐 AI(OpenAI 또는 Google)에 보내 대답을 받아요. 설정에서 끌 수 있어요.",
            "동네 친구를 찾을 때 구 이름은 Apple 지도 서비스에서 받아요. 음성 인식은 가능하면 iPhone 안에서, 아니면 Apple의 음성 인식을 써요.",
            "광고나 분석 도구는 넣지 않았어요.",
        ]),
        Part(title: "지우기", lines: [
            "설정 → 계정 · 서버 → 계정 삭제를 누르면 서버의 계정과 친구·편지·유리병 기록이 바로 지워져요. 이미 다른 사람에게 도착한 유리병의 아기는 그 사람에게 남아요.",
            "앱을 지우면 이 iPhone의 앱 보관함도 함께 지워져요. 남기고 싶은 사진은 먼저 사진 앱에 저장해 주세요.",
        ]),
        Part(title: "권한", lines: [
            "카메라: 사진과 동영상 촬영. 위치: 동네 친구, 지도 방명록, 주변 친구 보기(끌 수 있음). 근처 기기: 근처에서 친구 추가. 사진 추가: 사진 앱 저장. 마이크·음성 인식: 대화 모드. 알림: 유리병 도착과 아기 편지.",
        ]),
    ]

    var body: some View {
        List {
            Section {
                Text("스쿠카메라가 어떤 정보를 어디에 두는지 적어 두었어요.").font(.footnote)
            }.listRowBackground(Glass.row)
            ForEach(parts) { part in
                Section(part.title) {
                    ForEach(part.lines, id: \.self) { Text($0).font(.footnote) }
                }.listRowBackground(Glass.row)
            }
            Section {
                Text("2026년 11월 18일 기준").font(.caption2).foregroundStyle(.secondary)
            }.listRowBackground(Glass.row)
        }
        .glassSheet()
        .navigationTitle("개인정보 처리방침").navigationBarTitleDisplayMode(.inline)
    }
}
