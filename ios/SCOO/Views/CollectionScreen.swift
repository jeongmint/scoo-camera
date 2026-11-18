import SwiftUI

/// 친구 도감: the 25 characters, who you already have, and where in Korea to look for the rest.
struct CollectionScreen: View {
    @ObservedObject private var friends = FriendStore.shared
    @State private var exploration = Exploration.load()

    /// Characters this user has, or had before they left in a bottle.
    private var have: Set<String> { friends.seen.union(friends.friends.map(\.species)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 24) {
                    stat("모은 친구", "\(have.count) / \(Species.all.count)")
                    stat("다녀간 시군구", "\(exploration.visited.count) / \(Regions.all.count)")
                }
                Text("전국 229개 시군구마다 다섯 친구가 살아요. 처음엔 그중 한 마리만 오고, 다른 친구는 유리병 입양으로 만나요. 처음 가 본 시군구에서 사진을 찍으면 방문 도장이 찍혀요. 사는 곳이 적은 친구일수록 희귀해요.")
                    .font(.footnote).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                    ForEach(Species.all) { species in
                        card(species)
                    }
                }
                if !exploration.visited.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("다녀간 곳").font(.subheadline.weight(.semibold))
                        ForEach(Province.allCases.filter { exploration.visits(in: $0) > 0 }) { province in
                            let names = Regions.of(province).filter { exploration.visited[$0.id] != nil }.map(\.name)
                            Text("\(province.short) \(names.count)/\(Regions.of(province).count) · " + names.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
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
        let mine = friends.friends.first { $0.species == species.id }
        let homes = Regions.startsIn(species.id)
        return VStack(spacing: 4) {
            SpeciesPortrait(species: species)
                .frame(height: 70)
                .colorMultiply(owned ? .white : .black)
                .opacity(owned ? 1 : 0.18)
            Text(owned ? species.name : "???").font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption(owned: owned, mine: mine, homes: homes, species: species))
                .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(owned ? 0.7 : 0.4), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topTrailing) {
            if !homes.isEmpty && homes.count <= Self.rareAt {
                Text("희귀").font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Palette.moss, in: Capsule()).foregroundStyle(.white).padding(5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(owned ? species.name : "아직 못 만난 친구")
    }

    /// Characters living in this many places or fewer are marked rare.
    static let rareAt = 30

    private func caption(owned: Bool, mine: OwnedFriend?, homes: [Region], species: Species) -> String {
        if let mine {
            switch mine.how {
            case .starter: return "첫 친구"
            case .adopted: return mine.origin.map { "\($0)에서 입양" } ?? "유리병으로 입양"
            case .sea: return "바다에서 온 친구"
            case .event: return "이벤트 친구"
            case .explored: return mine.origin.map { "\($0)에서 만남" } ?? "탐험에서 만남"
            }
        }
        if owned { return "유리병으로 떠난 친구" }
        if let first = homes.first { return homes.count > 1 ? "힌트: \(first.title) 외 \(homes.count - 1)곳" : "힌트: \(first.title)" }
        return species.isEvent ? "이벤트" : "어딘가에서"
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
    }
}
