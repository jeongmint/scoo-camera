import SwiftUI
import UIKit

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dateStamp") private var dateStamp = true
    @AppStorage("autoSave") private var autoSave = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("날짜 인쇄", isOn: $dateStamp)
                    Toggle("사진 앱에도 자동 저장", isOn: $autoSave)
                } header: { Text("카메라") } footer: { Text("앱 앨범에는 항상 저장해요. 자동 저장을 켜면 다음 촬영 후 사진 추가 권한을 요청해요.") }
                Section("작은 친구") {
                    Text("자동 모드는 Apple Vision을 이용해 기기 안에서 음식 여부를 추정해요. 잘못 분류되면 촬영 전 음식 또는 일상 모드를 직접 골라 주세요.")
                    Text("사진 보너스는 빛과 픽셀의 변화를 계산해요. 미적 감동이나 사진의 예술성을 평가하는 AI는 아직 연결하지 않았어요.")
                }.font(.footnote)
                Section("내 사진, 내 기기에") {
                    Text("사진과 마리모 기록은 이 iPhone의 앱 보관함에 저장돼요. 서버 전송, 광고, 분석 SDK가 없어요. 앱을 삭제하면 보관함도 사라져요. 중요한 사진은 사진 앱에 저장해 주세요.").font(.footnote)
                    Button("iPhone 설정 열기") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                }
                Section { HStack { Text("SCOO").font(.headline); Spacer(); Text("0.1 · little moments, little growth").font(.caption2).foregroundStyle(.secondary) } }
            }.scrollContentBackground(.hidden).background(Palette.cream).tint(Palette.moss)
                .navigationTitle("작은 설정").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("완료") { dismiss() } } }
        }
    }
}
