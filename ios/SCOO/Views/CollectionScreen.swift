import SwiftUI

/// 친구 도감: the 25 characters, who you already have, and where to look for the rest.
struct CollectionScreen: View {
    @AppStorage("assignedCompanion") private var assignedRaw = ""
    @State private var exploration = Exploration.load()

    private var drawn: Set<String> {
        Set(Companion(rawValue: assignedRaw).map { Companion.owned(assigned: $0).map(\.rawValue) } ?? [])
    }
    private var have: Set<String> { drawn.union(exploration.collected) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 24) {
                    stat("모은 친구", "\(have.count) / \(Species.all.count)")
                    stat("다녀간 구", "\(exploration.visited.count) / \(SeoulDistrict.allCases.count)")
                }
                Text("서울의 새 구에서 처음 사진을 찍으면 그 동네 친구를 만나요. 만난 친구는 교배할 때 부모로 고를 수 있어요.")
                    .font(.footnote).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                    ForEach(Species.all) { species in
                        card(species)
                    }
                }
                if !exploration.visited.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("다녀간 구").font(.subheadline.weight(.semibold))
                        Text(SeoulDistrict.allCases.filter { exploration.visited[$0.rawValue] != nil }.map(\.rawValue).joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(22)
        }
        .background(Palette.cream)
        .foregroundStyle(Palette.ink)
        .navigationTitle("친구 도감")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { exploration = Exploration.load() }
    }

    private func card(_ species: Species) -> some View {
        let owned = have.contains(species.id)
        let meeting = exploration.met.first { $0.species == species.id }
        let home = SeoulDistrict.allCases.first { $0.special?.id == species.id }
        return VStack(spacing: 4) {
            SpeciesPortrait(species: species)
                .frame(height: 70)
                .colorMultiply(owned ? .white : .black)
                .opacity(owned ? 1 : 0.18)
            Text(owned ? species.name : "???").font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption(owned: owned, meeting: meeting, home: home, species: species))
                .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(owned ? 0.7 : 0.4), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(owned ? species.name : "아직 못 만난 친구")
    }

    private func caption(owned: Bool, meeting: Exploration.Meeting?, home: SeoulDistrict?, species: Species) -> String {
        if let meeting { return "\(meeting.district)에서 만남" }
        if owned { return species.isEvent ? "이벤트 친구" : "처음 받은 친구" }
        if let home { return "힌트: \(home.rawValue)" }
        return species.isEvent ? "이벤트" : "어딘가에서"
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
    }
}
