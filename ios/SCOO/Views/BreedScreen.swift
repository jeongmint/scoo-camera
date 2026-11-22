import SwiftUI
import UIKit

/// Pick parent A (shape and face) and parent B (main color and one feature), hatch an egg, meet the baby.
/// Babies grow into adults with a daisy after `BreedRules.photosToGrow` more photos.
struct BreedScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @StateObject private var store = BreedStore()
    @ObservedObject private var friends = FriendStore.shared
    @AppStorage("unlockAllFriends") private var unlockAll = false
    @State private var parentA: String?
    @State private var parentB: String?
    @State private var picking: Slot = .a
    @State private var hatching: Breed?
    @State private var showing: Breed?

    private enum Slot { case a, b }

    /// Friends in bloom (`FriendGrowth.bloomLevel`); 운영자 모드의 ‘모든 친구 열기’ opens everyone.
    private var owned: [Species] {
        Species.owned(friends.bloomed, unlockAll: unlockAll)
    }
    /// Friends still growing, with how far they are from bloom.
    private var growingNote: String {
        friends.friends.filter { $0.stage != .bloom }.compactMap { friend in
            friend.character.map { "\($0.name) LV.\(friend.growth.level)" }
        }.joined(separator: ", ")
    }
    /// Species plus babies in bloom (재교배).
    private var available: [BreedParent] { BreedRules.parents(species: owned, breeds: store.breeds, moments: moments) }
    private func parent(_ id: String?) -> BreedParent? { id.flatMap { id in available.first { $0.id == id } } }
    private func breed(for parent: BreedParent) -> Breed? { store.breeds.first { $0.parentID == parent.id } }
    private var problem: BreedRules.Problem? { BreedRules.problem(a: parent(parentA), b: parent(parentB), available: available) }
    private var moments: Int { garden.snapshot.moments }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("두 친구가 만나 아기가 태어나요").font(.headline)
                    Text("부모 A의 몸과 표정 + 부모 B의 색과 특징 하나").font(.caption).foregroundStyle(.secondary)
                }
                parents
                picker
                breedButton
                babies
            }
            .padding(22)
        }
        .background(Palette.cream)
        .foregroundStyle(Palette.ink)
        .navigationTitle("교배")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.freezeLegacy(moments: moments) }
        .fullScreenCover(item: $hatching) { baby in
            HatchView(breed: baby) { hatching = nil }
        }
        .sheet(item: $showing) { baby in
            BreedDetail(breed: baby, moments: moments)
        }
        .alert("알림", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { }
        } message: { Text(store.message ?? "") }
    }

    // MARK: Parents

    private var parents: some View {
        HStack(alignment: .top, spacing: 10) {
            slot(.a, id: parentA, role: "부모 A", gives: "몸 · 표정")
            Button {
                let first = parentA
                parentA = parentB
                parentB = first
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Image(systemName: "arrow.left.arrow.right").frame(width: 36, height: 36)
                    .background(.white.opacity(0.7), in: Circle())
            }
            .padding(.top, 40)
            .accessibilityLabel("부모 A와 B 바꾸기")
            slot(.b, id: parentB, role: "부모 B", gives: "색 · 특징 하나")
        }
    }

    private func slot(_ slot: Slot, id: String?, role: String, gives: String) -> some View {
        let chosen = parent(id)
        let active = picking == slot
        return Button { picking = slot } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.75))
                    RoundedRectangle(cornerRadius: 22).stroke(active ? Palette.moss : Palette.sage.opacity(0.3), lineWidth: active ? 2 : 1)
                    if let chosen {
                        portrait(chosen).padding(12)
                    } else {
                        Image(systemName: "plus").font(.title2).foregroundStyle(Palette.sage)
                    }
                }
                .frame(width: 118, height: 118)
                Text(role).font(.caption.weight(.semibold))
                Text(chosen?.name ?? gives).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(role), \(chosen?.name ?? "비어 있음")")
        .accessibilityHint("눌러서 \(role)를 고를 차례로 바꿔요")
    }

    // MARK: Picker

    @ViewBuilder
    private var picker: some View {
        if available.count < 2 {
            Text("교배하려면 활짝 만개한(레벨 \(FriendGrowth.bloomLevel)) 친구가 둘 이상 있어야 해요. 지금 만개한 친구: \(owned.isEmpty ? "아직 없음" : owned.map(\.name).joined(separator: ", ")). \(growingNote.isEmpty ? "" : "자라는 중: \(growingNote). ")친구를 카메라에 띄워 두고 함께 찍으면 그 친구가 자라요.")
                .font(.footnote).foregroundStyle(.secondary)
                .padding(16).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(picking == .a ? "부모 A를 골라요" : "부모 B를 골라요").font(.subheadline.weight(.medium))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(available) { candidate in
                        let chosen = candidate.id == parentA || candidate.id == parentB
                        Button { choose(candidate) } label: {
                            VStack(spacing: 3) {
                                portrait(candidate).frame(height: 54)
                                Text(candidate.name).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .background(chosen ? Palette.sage.opacity(0.22) : .white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                if candidate.isBreed {
                                    Text("\(candidate.generation)세대").font(.system(size: 8, weight: .semibold))
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Palette.moss, in: Capsule()).foregroundStyle(.white).padding(4)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(candidate.name + (candidate.isBreed ? ", 만개한 아기 \(candidate.generation)세대" : (candidate.species?.isEvent == true ? ", 이벤트" : "")))
                    }
                }
                if store.breeds.contains(where: { $0.stage(moments: moments) != .bloom }) {
                    Text("아기가 만개하면 부모로 고를 수 있어요.").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func choose(_ candidate: BreedParent) {
        UISelectionFeedbackGenerator().selectionChanged()
        switch picking {
        case .a:
            parentA = candidate.id
            if parentB == nil || parentB == candidate.id { picking = .b }
        case .b:
            parentB = candidate.id
        }
    }

    @ViewBuilder
    private func portrait(_ candidate: BreedParent) -> some View {
        if candidate.isBreed, let baby = breed(for: candidate) {
            BreedPortrait(breed: baby, stage: .bloom)
        } else if let species = candidate.species {
            SpeciesPortrait(species: species)
        }
    }

    // MARK: Breed

    private var breedButton: some View {
        VStack(spacing: 8) {
            Button { hatch() } label: {
                Label("교배하기", systemImage: "heart.fill").font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(problem == nil ? Palette.moss : Palette.sage.opacity(0.35), in: Capsule())
                    .foregroundStyle(.white)
            }
            .disabled(problem != nil)
            if let problem, parentA != nil || parentB != nil {
                Text(problem.message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func hatch() {
        guard let a = parent(parentA), let b = parent(parentB), problem == nil else { return }
        do {
            let baby = try store.hatch(a, b, moments: moments)
            parentA = nil
            parentB = nil
            picking = .a
            hatching = baby
        } catch {
            store.message = "아기를 저장하지 못했어요. \(error.localizedDescription)"
        }
    }

    // MARK: Babies

    @ViewBuilder
    private var babies: some View {
        if !store.breeds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("우리 아기들").font(.subheadline.weight(.medium))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(store.breeds) { baby in
                        let stage = baby.stage(moments: moments)
                        let level = baby.growth(moments: moments).level
                        Button { showing = baby } label: {
                            VStack(spacing: 4) {
                                BreedPortrait(breed: baby, stage: stage).frame(height: 84)
                                Text(baby.title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                                Text((baby.origin.map { "\($0) 출신 · " } ?? "") + (stage == .bloom ? "만개 · LV.\(level)" : "\(stage.title) · LV.\(level)"))
                                    .font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Hatching

private struct HatchView: View {
    let breed: Breed
    let done: () -> Void
    @State private var wobble = false
    @State private var cracked = false
    @State private var drawingLong = false
    @State private var drawNote: String?

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()
            VStack(spacing: 22) {
                if cracked {
                    BreedPortrait(breed: breed).frame(width: 240, height: 240)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                    Text("태어났어요!").font(.title2.weight(.semibold))
                    Text(breed.title).font(.subheadline).foregroundStyle(.secondary)
                    if let drawNote { Text(drawNote).font(.caption2).foregroundStyle(.secondary) }
                    Text("사진을 \(BreedRules.photosToGrowing)장 더 찍으면 성장, \(BreedRules.photosToGrow)장이면 데이지를 단 만개. 만개하면 다시 교배할 수 있어요.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("반가워!") { done() }
                        .font(.headline).padding(.horizontal, 36).padding(.vertical, 12)
                        .background(Palette.moss, in: Capsule()).foregroundStyle(.white)
                } else {
                    Egg()
                        .frame(width: 150, height: 190)
                        .rotationEffect(.degrees(wobble ? 9 : -9), anchor: .bottom)
                        .animation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true), value: wobble)
                    Text(drawingLong ? "두근두근… 아기 모습을 그리는 중이에요" : "두근두근…").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(30)
            .foregroundStyle(Palette.ink)
        }
        .task {
            wobble = true
            // Draw the baby on the server while the egg wobbles (pairs drawn before come back at once).
            async let drawing: String? = draw()
            try? await Task.sleep(for: .seconds(2.2))
            drawingLong = true
            drawNote = await drawing
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { cracked = true }
        }
    }
}

extension HatchView {
    /// Returns a note when the picture could not be drawn (the stand-in is shown instead).
    @MainActor
    func draw() async -> String? {
        guard BreedArt.canDraw, !BreedArt.hasArt(breed) else { return nil }
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await BreedArt.fetch(breed) }
                group.addTask { try await Task.sleep(for: .seconds(90)); throw SCOOError.message("그림이 오래 걸려서 다음에 다시 그려 볼게요.") }
                _ = try await group.next()
                group.cancelAll()
            }
            return nil
        } catch {
            return "지금은 임시 그림이에요. \(error.localizedDescription)"
        }
    }
}

private struct Egg: View {
    var body: some View {
        ZStack {
            Ellipse().fill(LinearGradient(colors: [.white, Color(red: 0.96, green: 0.92, blue: 0.84)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 8)
            ForEach(0..<5, id: \.self) { index in
                let spots: [(CGFloat, CGFloat, CGFloat)] = [(-0.18, -0.22, 0.13), (0.2, -0.05, 0.1), (-0.05, 0.12, 0.16),
                                                            (0.22, 0.26, 0.09), (-0.24, 0.3, 0.08)]
                let spot = spots[index]
                GeometryReader { proxy in
                    Circle().fill(Palette.sage.opacity(0.35))
                        .frame(width: proxy.size.width * spot.2, height: proxy.size.width * spot.2)
                        .position(x: proxy.size.width * (0.5 + spot.0), y: proxy.size.height * (0.5 + spot.1))
                }
            }
        }
        .accessibilityLabel("흔들리는 알")
    }
}

// MARK: - Detail

/// One bred baby up close (also opened from 친구 상자).
struct BreedDetail: View {
    let breed: Breed
    let moments: Int
    @Environment(\.dismiss) private var dismiss
    @AppStorage("companion") private var companionRaw = ""
    @State private var drawing = false
    @State private var redrawn = false
    @State private var drawError: String?

    private func redraw() {
        drawing = true
        drawError = nil
        Task {
            defer { drawing = false }
            do { try await BreedArt.fetch(breed); redrawn = true }
            catch { drawError = error.localizedDescription }
        }
    }

    var body: some View {
        let adult = breed.isAdult(moments: moments)
        let stage = breed.stage(moments: moments)
        let growth = breed.growth(moments: moments)
        let floating = companionRaw == Floater.tag(breed)
        let drawn = BreedArt.hasArt(breed)
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    BreedPortrait(breed: breed, stage: stage).frame(width: 240, height: 240)
                    Text(breed.title).font(.title3.weight(.semibold))
                    if let generation = breed.generation, generation > 1 {
                        Text("\(generation)세대 · 교배종끼리 만나 태어났어요").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        ForEach([GrowthStage.baby, .growing, .bloom], id: \.rawValue) { step in
                            Text(step.title).font(.caption.weight(step == stage ? .bold : .regular))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(step <= stage ? Palette.sage.opacity(0.35) : .white.opacity(0.6), in: Capsule())
                        }
                    }
                    if adult {
                        Text("활짝 핀 만개예요. 이제 부모가 되어 다시 교배할 수 있어요.").font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if let left = FriendGrowth.toNextStage(xp: breed.xp(moments: moments)) {
                        Text("\(stage == .baby ? "성장기" : "만개")까지 \(left) EXP").font(.subheadline)
                    }
                    VStack(spacing: 6) {
                        HStack {
                            Text("LV.\(growth.level)").font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            Spacer()
                            Text("\(growth.progress) / 100 EXP").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(growth.progress), total: 100).tint(Palette.sage)
                        Text("함께 찍은 사진 \(breed.together ?? 0)장 · 떠 있는 동안 찍은 사진의 EXP는 이 아기만 받아요.")
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 260)
                    Button {
                        companionRaw = floating ? "" : Floater.tag(breed)
                        dismiss()
                    } label: {
                        Text(floating ? "기본 모리로 돌아가기" : "카메라에 띄우기")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: 260).padding(.vertical, 12)
                            .background(Palette.moss, in: Capsule()).foregroundStyle(.white)
                    }
                    HStack(spacing: 22) {
                        parent(breed.mother, name: breed.nameA, role: "부모 A · 몸과 표정")
                        parent(breed.father, name: breed.nameB, role: "부모 B · 색과 특징")
                    }
                    Text((breed.adopted == true ? "우리 집에 온 날 " : "태어난 날 ") + breed.born.formatted(date: .long, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                    if let origin = breed.origin {
                        Label("\(origin) 출신 · 유리병을 타고 왔어요", systemImage: "water.waves").font(.caption).foregroundStyle(.secondary)
                    }
                    if !drawn && !redrawn {
                        Text("아직 이 조합의 그림이 없어서 부모 A 모양에 부모 B 색을 입힌 임시 그림을 보여줘요.")
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if BreedArt.canDraw {
                            Button(drawing ? "그리는 중…" : "진짜 모습 그려 받기") { redraw() }
                                .disabled(drawing).buttonStyle(.borderedProminent)
                        }
                        if let drawError { Text(drawError).font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                .padding(24)
            }
            .background(Palette.cream)
            .foregroundStyle(Palette.ink)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
        .presentationDetents([.large])
        .tint(Palette.moss)
    }

    /// `name` is set when the parent was itself a bred baby; the picture then shows the species it came from.
    private func parent(_ species: Species?, name: String?, role: String) -> some View {
        VStack(spacing: 4) {
            if let species { SpeciesPortrait(species: species).frame(width: 64, height: 64) }
            Text(name ?? species?.name ?? "?").font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(role).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}
