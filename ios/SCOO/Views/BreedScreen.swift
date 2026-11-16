import SwiftUI
import UIKit

/// Pick parent A (shape and face) and parent B (main color and one feature), hatch an egg, meet the baby.
/// Babies grow into adults with a daisy after `BreedRules.photosToGrow` more photos.
struct BreedScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @StateObject private var store = BreedStore()
    @AppStorage("assignedCompanion") private var assignedRaw = ""
    @AppStorage("unlockAllFriends") private var unlockAll = false
    @State private var parentA: String?
    @State private var parentB: String?
    @State private var picking: Slot = .a
    @State private var hatching: Breed?
    @State private var showing: Breed?

    private enum Slot { case a, b }

    private var owned: [Species] { Species.owned(assigned: Companion(rawValue: assignedRaw), unlockAll: unlockAll) }
    private var problem: BreedRules.Problem? { BreedRules.problem(a: parentA, b: parentB, owned: owned) }
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
        .onAppear { store.load() }
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
        let species = id.flatMap(Species.find)
        let active = picking == slot
        return Button { picking = slot } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.75))
                    RoundedRectangle(cornerRadius: 22).stroke(active ? Palette.moss : Palette.sage.opacity(0.3), lineWidth: active ? 2 : 1)
                    if let species {
                        SpeciesPortrait(species: species).padding(12)
                    } else {
                        Image(systemName: "plus").font(.title2).foregroundStyle(Palette.sage)
                    }
                }
                .frame(width: 118, height: 118)
                Text(role).font(.caption.weight(.semibold))
                Text(species?.name ?? gives).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(role), \(species?.name ?? "비어 있음")")
        .accessibilityHint("눌러서 \(role)를 고를 차례로 바꿔요")
    }

    // MARK: Picker

    @ViewBuilder
    private var picker: some View {
        if owned.count < 2 {
            Text("교배하려면 친구가 두 명 이상 있어야 해요. 지금은 \(owned.map(\.name).joined(separator: ", ")). 설정 > 동네 친구(테스트)에서 ‘모든 친구 열기’를 켜면 전부 시험해 볼 수 있어요.")
                .font(.footnote).foregroundStyle(.secondary)
                .padding(16).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(picking == .a ? "부모 A를 골라요" : "부모 B를 골라요").font(.subheadline.weight(.medium))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(owned) { species in
                        let chosen = species.id == parentA || species.id == parentB
                        Button { choose(species) } label: {
                            VStack(spacing: 3) {
                                SpeciesPortrait(species: species).frame(height: 54)
                                Text(species.name).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .background(chosen ? Palette.sage.opacity(0.22) : .white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(species.name + (species.isEvent ? ", 이벤트" : ""))
                    }
                }
            }
        }
    }

    private func choose(_ species: Species) {
        UISelectionFeedbackGenerator().selectionChanged()
        switch picking {
        case .a:
            parentA = species.id
            if parentB == nil || parentB == species.id { picking = .b }
        case .b:
            parentB = species.id
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
        guard let a = parentA, let b = parentB, problem == nil else { return }
        do {
            let baby = try store.hatch(a: a, b: b, moments: moments)
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
                        let adult = baby.isAdult(moments: moments)
                        Button { showing = baby } label: {
                            VStack(spacing: 4) {
                                BreedPortrait(breed: baby, adult: adult).frame(height: 84)
                                Text(baby.title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                                Text((baby.origin.map { "\($0) 출신 · " } ?? "") + (adult ? "성체" : "아기 · 사진 \(baby.photosLeft(moments: moments))장 더"))
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

    var body: some View {
        ZStack {
            Palette.cream.ignoresSafeArea()
            VStack(spacing: 22) {
                if cracked {
                    BreedPortrait(breed: breed).frame(width: 240, height: 240)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                    Text("태어났어요!").font(.title2.weight(.semibold))
                    Text(breed.title).font(.subheadline).foregroundStyle(.secondary)
                    Text("사진을 \(BreedRules.photosToGrow)장 더 찍으면 데이지를 단 성체로 자라요.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("반가워!") { done() }
                        .font(.headline).padding(.horizontal, 36).padding(.vertical, 12)
                        .background(Palette.moss, in: Capsule()).foregroundStyle(.white)
                } else {
                    Egg()
                        .frame(width: 150, height: 190)
                        .rotationEffect(.degrees(wobble ? 9 : -9), anchor: .bottom)
                        .animation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true), value: wobble)
                    Text("두근두근…").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(30)
            .foregroundStyle(Palette.ink)
        }
        .task {
            wobble = true
            try? await Task.sleep(for: .seconds(2.2))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { cracked = true }
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

private struct BreedDetail: View {
    let breed: Breed
    let moments: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let adult = breed.isAdult(moments: moments)
        let drawn = UIImage(named: breed.babyAsset) != nil
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    BreedPortrait(breed: breed, adult: adult).frame(width: 240, height: 240)
                    Text(breed.title).font(.title3.weight(.semibold))
                    if adult {
                        Text("다 자란 성체예요").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 6) {
                            Text("아기 · 사진 \(breed.photosLeft(moments: moments))장 더 찍으면 성체").font(.subheadline)
                            ProgressView(value: Double(breed.photosSinceBirth(moments: moments)), total: Double(BreedRules.photosToGrow))
                                .tint(Palette.sage).frame(maxWidth: 220)
                        }
                    }
                    HStack(spacing: 22) {
                        parent(breed.mother, role: "부모 A · 몸과 표정")
                        parent(breed.father, role: "부모 B · 색과 특징")
                    }
                    Text((breed.adopted == true ? "우리 집에 온 날 " : "태어난 날 ") + breed.born.formatted(date: .long, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                    if let origin = breed.origin {
                        Label("\(origin) 출신 · 유리병을 타고 왔어요", systemImage: "water.waves").font(.caption).foregroundStyle(.secondary)
                    }
                    if !drawn {
                        Text("아직 이 조합의 그림이 없어서 부모 A 모양에 부모 B 색을 입힌 임시 그림을 보여줘요. 그림을 만들어 Breed-\(breed.key)로 넣으면 바로 바뀌어요.")
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
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

    private func parent(_ species: Species?, role: String) -> some View {
        VStack(spacing: 4) {
            if let species { SpeciesPortrait(species: species).frame(width: 64, height: 64) }
            Text(species?.name ?? "?").font(.caption.weight(.medium))
            Text(role).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}
