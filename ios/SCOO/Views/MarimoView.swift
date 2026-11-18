import SwiftUI
import UIKit

struct MarimoView: View {
    var size: CGFloat = 110
    var happy = false
    /// Overrides the face. When nil, `happy` picks between 방긋 and 평소 미소.
    var expression: MoriExpression? = nil
    var floats = true
    @State private var floating = false
    private var face: MoriExpression { expression ?? (happy ? .smile : .normal) }

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
            drawFace(in: &context, center: center, radius: radius)
        }
        .frame(width: size, height: size)
        .offset(y: floats ? (floating ? -4 : 3) : 0)
        .rotationEffect(.degrees(floats ? (floating ? (face != .normal ? 6 : 2) : -2) : 0))
        .animation(.easeInOut(duration: face != .normal ? 0.3 : 2.5).repeatForever(autoreverses: true), value: floating)
        .onAppear { floating = true }
        .accessibilityLabel("보송한 초록 마리모")
    }

    /// Eyes, mouth and cheeks for the current expression, in the same place the plain face always had them.
    private func drawFace(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let s = size
        let ink = GraphicsContext.Shading.color(Palette.ink)
        let stroke = StrokeStyle(lineWidth: max(1, s / 140), lineCap: .round)
        let eyeXs = [center.x - radius * 0.19, center.x + radius * 0.19]
        let eyeTop = center.y + s * 0.012
        let mouthY = center.y + s * 0.055

        func dots(width: CGFloat, height: CGFloat) -> Path {
            var path = Path()
            for x in eyeXs { path.addEllipse(in: CGRect(x: x - width / 2, y: eyeTop, width: width, height: height)) }
            return path
        }
        /// Closed eyes: positive `bow` bends up (⌒), negative bends down (‿).
        func lids(bow: CGFloat) -> Path {
            var path = Path()
            let y = eyeTop + s * 0.02
            for x in eyeXs {
                path.move(to: CGPoint(x: x - s * 0.017, y: y))
                path.addQuadCurve(to: CGPoint(x: x + s * 0.017, y: y), control: CGPoint(x: x, y: y - bow * 2))
            }
            return path
        }
        func smile() -> Path {
            var path = Path()
            path.addArc(center: CGPoint(x: center.x, y: mouthY), radius: s * 0.035,
                        startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false)
            return path
        }
        func openMouth(width: CGFloat, depth: CGFloat) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: center.x - width / 2, y: mouthY))
            path.addQuadCurve(to: CGPoint(x: center.x + width / 2, y: mouthY), control: CGPoint(x: center.x, y: mouthY + depth * 2))
            path.closeSubpath()
            return path
        }
        func cheeks() -> Path {
            var path = Path()
            for (index, x) in eyeXs.enumerated() {
                let outward = index == 0 ? -s * 0.045 : s * 0.045
                path.addEllipse(in: CGRect(x: x + outward - s * 0.018, y: eyeTop + s * 0.04, width: s * 0.036, height: s * 0.02))
            }
            return path
        }
        let blush = GraphicsContext.Shading.color(Color(red: 1, green: 0.62, blue: 0.62).opacity(0.5))
        let tongue = GraphicsContext.Shading.color(Color(red: 1, green: 0.55, blue: 0.58))

        switch face {
        case .normal:
            context.fill(dots(width: s * 0.025, height: s * 0.035), with: ink)
            context.stroke(smile(), with: ink, style: stroke)
        case .shutter:
            context.stroke(lids(bow: -s * 0.014), with: ink, style: stroke)
            context.stroke(smile(), with: ink, style: stroke)
        case .surprised:
            var brows = Path()
            for x in eyeXs {
                brows.move(to: CGPoint(x: x - s * 0.015, y: eyeTop - s * 0.012))
                brows.addQuadCurve(to: CGPoint(x: x + s * 0.015, y: eyeTop - s * 0.012), control: CGPoint(x: x, y: eyeTop - s * 0.03))
            }
            context.stroke(brows, with: ink, style: StrokeStyle(lineWidth: max(0.8, s / 190), lineCap: .round))
            context.fill(dots(width: s * 0.026, height: s * 0.045), with: ink)
            context.stroke(Path(ellipseIn: CGRect(x: center.x - s * 0.011, y: mouthY + s * 0.012, width: s * 0.022, height: s * 0.028)),
                           with: ink, style: stroke)
        case .smile:
            context.fill(cheeks(), with: blush)
            context.stroke(lids(bow: s * 0.02), with: ink, style: stroke)
            context.fill(openMouth(width: s * 0.08, depth: s * 0.034), with: ink)
        case .awe:
            context.fill(cheeks(), with: blush)
            context.fill(dots(width: s * 0.034, height: s * 0.042), with: ink)
            var sparkles = Path()
            for x in eyeXs { sparkles.addEllipse(in: CGRect(x: x - s * 0.011, y: eyeTop + s * 0.006, width: s * 0.011, height: s * 0.011)) }
            context.fill(sparkles, with: .color(.white.opacity(0.95)))
            context.fill(openMouth(width: s * 0.056, depth: s * 0.03), with: ink)
        case .yum:
            context.stroke(lids(bow: s * 0.02), with: ink, style: stroke)
            context.fill(Path(ellipseIn: CGRect(x: center.x + s * 0.004, y: mouthY + s * 0.03, width: s * 0.024, height: s * 0.03)), with: tongue)
            context.stroke(smile(), with: ink, style: stroke)
        }
    }
}

struct GardenScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var happy = false
    @State private var renaming = false
    @State private var name = ""
    @State private var line = "오늘은 어떤 순간을 먹을까?"
    @State private var film: RenderedFilm?
    @State private var walking = WalkMode.isActive
    @State private var walkMessage: String?
    @StateObject private var locator = DistrictLocator()
    @AppStorage("keepsakePhotoID") private var keepsakeID = ""
    @AppStorage("assignedCompanion") private var assignedRaw = ""
    @AppStorage("companion") private var companionRaw = ""

    private struct RenderedFilm: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var personality: Personality { Personality.of(garden.snapshot.photos) }
    private var todayPhotos: [PhotoRecord] { garden.snapshot.photos.filter { Calendar.current.isDateInToday($0.date) } }
    /// The friend floating in the camera, if one was picked (otherwise Mori).
    private var floatingFriend: Species? {
        guard let picked = Species.find(companionRaw), FriendStore.shared.owns(picked.id) else { return nil }
        return picked
    }

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
                        Spacer(); stat("성격", personality.title)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label(personality.title, systemImage: "sparkles").font(.subheadline.weight(.medium))
                        Text(personality.habit).font(.caption).foregroundStyle(.secondary)
                        Text("자주 찍는 사진에 따라 성격이 조금씩 달라져요.").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                    if let keepsake = Keepsake.photo(in: garden.snapshot.photos, chosen: keepsakeID) {
                        HStack(spacing: 14) {
                            PhotoThumbnail(url: garden.fileURL(for: keepsake))
                                .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(garden.snapshot.name)의 애착 사진").font(.subheadline.weight(.medium))
                                Text(keepsake.date.formatted(date: .long, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                                Text(keepsake.id.uuidString == keepsakeID ? "네가 골라 준 사진이에요." : "제일 반짝이던 순간을 골라 간직하고 있어요. 앨범에서 바꿀 수 있어요.")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                    }
                    Button { makeFilm() } label: {
                        menuRow(todayPhotos.isEmpty ? "오늘 찍은 사진이 생기면 필름을 만들어요" : "오늘의 작은 필름 만들기 (\(min(4, todayPhotos.count))장)",
                                systemImage: "film")
                    }
                    .buttonStyle(.plain)
                    .disabled(todayPhotos.isEmpty)
                    VStack(spacing: 10) {
                        NavigationLink { CollectionScreen() } label: { menuRow("친구 도감", systemImage: "square.grid.3x3") }
                        NavigationLink { BreedScreen() } label: { menuRow("교배하러 가기", systemImage: "heart.circle") }
                        NavigationLink { BottleScreen() } label: { menuRow("유리병 입양", systemImage: "water.waves") }
                        NavigationLink { InboxScreen() } label: { menuRow("편지함 · 친구", systemImage: "envelope") }
                        Button { toggleWalk() } label: {
                            menuRow(walking ? "산책 모드 끝내기" : "산책 모드 시작 (잠금 화면에 함께)", systemImage: walking ? "figure.walk.departure" : "figure.walk")
                        }
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("순간을 먹고, 조금씩 자라요", systemImage: "leaf") .font(.subheadline.weight(.medium))
                        Text("일상 사진은 +12, 음식 사진은 +20 EXP. 빛과 선명도에 따라 최대 +10을 더 받아요. 100 EXP마다 한 레벨씩 자라요.").font(.caption).lineSpacing(5).foregroundStyle(.secondary)
                        Text("자동 모드는 기기 안에서 음식 여부를 추정해요. 사진 보너스는 밝기·명암·픽셀 변화량을 이용한 간단한 계산이에요.").font(.caption2).lineSpacing(4).foregroundStyle(.secondary)
                    }.padding(20).background(Palette.sage.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }.padding(26)
            }.background(Palette.cream).foregroundStyle(Palette.ink)
                .navigationTitle("작은 친구").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
                .sheet(item: $film) { film in FilmStripSheet(image: film.image) }
                .onAppear { walking = WalkMode.isActive }
                .alert("산책 모드", isPresented: Binding(get: { walkMessage != nil }, set: { if !$0 { walkMessage = nil } })) {
                    Button("확인") { walkMessage = nil }
                } message: { Text(walkMessage ?? "") }
                .alert("마리모 이름", isPresented: $renaming) {
                    TextField("이름 (최대 12자)", text: $name)
                    Button("저장") { Task { await garden.rename(name) } }
                    Button("취소", role: .cancel) { }
                }
        }.tint(Palette.moss)
    }
    private func toggleWalk() {
        if walking {
            WalkMode.end()
            walking = false
            return
        }
        do {
            try WalkMode.start(heroName: floatingFriend?.name ?? garden.snapshot.name, district: nil)
            walking = true
            WidgetBridge.refresh()
            // Fill in the district once it is known.
            Task {
                if case .success(let region) = await locator.currentRegion() {
                    WalkMode.update(district: region.title)
                }
            }
        } catch {
            walkMessage = error.localizedDescription
        }
    }

    private func makeFilm() {
        let records = todayPhotos
        let images = FilmStrip.images(for: records, url: garden.fileURL(for:))
        guard !images.isEmpty else { return }
        let friend = floatingFriend
        let strip = FilmStrip(photos: images, date: Date(),
                              caption: FilmStrip.caption(friend: friend?.name ?? garden.snapshot.name, photos: Array(records.prefix(4))),
                              friendAsset: friend?.assetName)
        let renderer = ImageRenderer(content: strip)
        renderer.scale = 2
        if let image = renderer.uiImage { film = RenderedFilm(image: image) }
    }

    private func menuRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(.subheadline.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right").font(.caption)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Text(title).font(.caption2).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.medium)) }
    }
}
