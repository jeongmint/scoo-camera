import SwiftUI
import UIKit

struct MarimoView: View {
    var size: CGFloat = 110
    var happy = false
    var floats = true
    @State private var floating = false

    var body: some View {
        Canvas { context, bounds in
            let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
            let radius = bounds.width * 0.40
            let ball = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.fill(ball, with: .radialGradient(Gradient(colors: [Color(red: 0.48, green: 0.65, blue: 0.29), Palette.moss, Color(red: 0.10, green: 0.24, blue: 0.14)]),
                                                       center: CGPoint(x: center.x - radius * 0.4, y: center.y - radius * 0.5), startRadius: 0, endRadius: radius * 1.7))
            var seed: UInt64 = 4182
            func random() -> Double { seed = (seed &* 16807) % 2147483647; return Double(seed) / 2147483647 }
            for _ in 0..<2400 {
                let angle = CGFloat(random() * .pi * 2)
                let distance = CGFloat(sqrt(random())) * radius
                let x = center.x + cos(angle) * distance
                let y = center.y + sin(angle) * distance
                let length = radius * (0.025 + CGFloat(random()) * 0.05)
                var strand = Path()
                strand.move(to: CGPoint(x: x, y: y))
                strand.addLine(to: CGPoint(x: x + cos(angle) * length * 0.6, y: y - length))
                context.stroke(strand, with: .color(Color(hue: 0.23 + random() * 0.08, saturation: 0.45 + random() * 0.2,
                                                          brightness: 0.25 + random() * 0.38).opacity(0.8)), lineWidth: max(0.45, size / 230))
            }
            for offset in [-0.19, 0.19] {
                let eye = CGRect(x: center.x + radius * CGFloat(offset) - size * 0.012, y: center.y + size * 0.012,
                                 width: size * 0.025, height: happy ? size * 0.018 : size * 0.035)
                context.fill(Path(ellipseIn: eye), with: .color(Palette.ink))
            }
            var smile = Path()
            smile.addArc(center: CGPoint(x: center.x, y: center.y + size * 0.055), radius: size * 0.035,
                         startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false)
            context.stroke(smile, with: .color(Palette.ink), style: StrokeStyle(lineWidth: max(1, size / 140), lineCap: .round))
        }
        .frame(width: size, height: size)
        .offset(y: floats ? (floating ? -4 : 3) : 0)
        .rotationEffect(.degrees(floats ? (floating ? (happy ? 6 : 2) : -2) : 0))
        .animation(.easeInOut(duration: happy ? 0.3 : 2.5).repeatForever(autoreverses: true), value: floating)
        .onAppear { floating = true }
        .accessibilityLabel("보송한 초록 마리모")
    }
}

struct GardenScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var happy = false
    @State private var renaming = false
    @State private var name = ""
    @State private var line = "오늘은 어떤 순간을 먹을까?"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 27) {
                    Text("YOUR LITTLE FLOATING FRIEND").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(Palette.sage)
                    HStack(alignment: .firstTextBaseline) {
                        Text("LV. \(String(format: "%02d", garden.growth.level))").font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.sage)
                        Button { name = garden.snapshot.name; renaming = true } label: {
                            HStack { Text(garden.snapshot.name).font(.system(size: 31, weight: .semibold)); Image(systemName: "pencil").font(.caption) }
                        }
                        Spacer()
                        Text("DAY \(garden.day)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Text(line).font(.footnote).padding(.horizontal, 17).padding(.vertical, 11).background(.white.opacity(0.6), in: Capsule())
                    Button {
                        happy.toggle(); line = happy ? "보송보송, 네 순간이 나를 키워!" : "다음 사진도 기다릴게."
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: { MarimoView(size: min(240, 185 + CGFloat(sqrt(Double(max(0, garden.snapshot.experience)))) * 0.6), happy: happy).frame(height: 260) }.buttonStyle(.plain).accessibilityLabel("마리모 쓰다듬기")
                    VStack(spacing: 10) {
                        HStack { Text("조금씩, 무럭무럭"); Spacer(); Text("\(garden.growth.progress) / 100 EXP").monospacedDigit() }.font(.caption2)
                        ProgressView(value: Double(garden.growth.progress), total: 100).tint(Palette.sage)
                    }.foregroundStyle(Palette.moss)
                    HStack {
                        stat("먹은 순간", "\(garden.snapshot.moments) 컷")
                        Spacer(); stat("지금의 크기", String(format: "%.1f cm", garden.growth.size))
                        Spacer(); stat("기분", "몽글몽글")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label("순간을 먹고, 조금씩 자라요", systemImage: "leaf") .font(.subheadline.weight(.medium))
                        Text("일상 사진은 +12, 음식 사진은 +20 EXP. 빛과 선명도에 따라 최대 +10을 더 받아요. 100 EXP마다 한 레벨씩 자라요.").font(.caption).lineSpacing(5).foregroundStyle(.secondary)
                        Text("자동 모드는 기기 안에서 음식 여부를 추정해요. 사진 보너스는 밝기·명암·픽셀 변화량을 이용한 간단한 계산이에요.").font(.caption2).lineSpacing(4).foregroundStyle(.secondary)
                    }.padding(20).background(Palette.sage.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }.padding(26)
            }.background(Palette.cream).foregroundStyle(Palette.ink)
                .navigationTitle("작은 친구").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
                .alert("마리모 이름", isPresented: $renaming) {
                    TextField("이름 (최대 12자)", text: $name)
                    Button("저장") { Task { await garden.rename(name) } }
                    Button("취소", role: .cancel) { }
                }
        }.tint(Palette.moss)
    }
    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Text(title).font(.caption2).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.medium)) }
    }
}
