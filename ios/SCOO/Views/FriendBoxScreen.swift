import SwiftUI

/// 친구 상자: every friend this user has, each with its own level, EXP and growth stage.
/// A friend grows from photos taken while it floats on the camera; 기본 모리 keeps the garden's own EXP.
struct FriendBoxScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @ObservedObject private var friends = FriendStore.shared
    @AppStorage("companion") private var companionRaw = ""
    @State private var picked: OwnedFriend?

    private var bloomCount: Int { friends.friends.filter { $0.stage == .bloom }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 24) {
                    stat("함께하는 친구", "\(friends.friends.count)마리")
                    stat("만개한 친구", "\(bloomCount)마리")
                }
                Text("카메라에 띄워 둔 친구가 함께 찍은 사진만큼 자라요. 레벨 \(FriendGrowth.growingLevel)에 성장기, 레벨 \(FriendGrowth.bloomLevel)에 활짝 만개하고, 만개한 친구끼리 교배할 수 있어요.")
                    .font(.footnote).foregroundStyle(.secondary)
                moriCard
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                    ForEach(friends.friends) { friend in
                        Button { picked = friend } label: { cell(friend) }.buttonStyle(.plain)
                    }
                }
                if friends.friends.isEmpty {
                    Text("아직 친구가 없어요. 카메라를 켜면 지금 있는 동네의 친구가 찾아와요.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(22)
        }
        .background(Palette.cream)
        .foregroundStyle(Palette.ink)
        .navigationTitle("친구 상자")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $picked) { friend in
            FriendDetailSheet(friendID: friend.id).presentationDetents([.medium, .large])
        }
    }

    /// 기본 모리: the one floating when no friend is picked, growing with the garden's EXP.
    private var moriCard: some View {
        let growth = garden.growth
        return HStack(spacing: 14) {
            Image("Companion-mori").resizable().scaledToFit().frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(garden.snapshot.name).font(.subheadline.weight(.semibold))
                    Text("기본 모리").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("LV.\(growth.level)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                ProgressView(value: Double(growth.progress), total: 100).tint(Palette.sage)
                HStack {
                    Text("다음 레벨까지 \(100 - growth.progress) EXP")
                    Spacer()
                    if companionRaw.isEmpty { Text("지금 떠 있어요").foregroundStyle(Palette.moss) }
                    else { Button("띄우기") { companionRaw = "" }.font(.caption.weight(.medium)) }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.moss.opacity(companionRaw.isEmpty ? 0.6 : 0), lineWidth: 1.5))
    }

    private func cell(_ friend: OwnedFriend) -> some View {
        let floating = companionRaw == friend.species && friends.friend(for: friend.species)?.id == friend.id
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if let species = friend.character {
                    SpeciesPortrait(species: species)
                        .scaleEffect(friend.stage.scale)
                        .frame(height: 56)
                }
                Text("\(friend.growth.level)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(friend.stage == .bloom ? Palette.moss : Palette.sage, in: Circle())
            }
            Text(friend.character?.name ?? friend.species)
                .font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            ProgressView(value: Double(friend.growth.progress), total: 100).tint(Palette.sage).scaleEffect(y: 0.7)
            Text(friend.stage == .bloom ? "🌼 만개" : friend.stage.title)
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.moss.opacity(floating ? 0.7 : 0), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(friend.character?.name ?? friend.species), 레벨 \(friend.growth.level), \(friend.stage.title)\(floating ? ", 지금 떠 있어요" : "")")
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }
}

/// One friend up close: level, EXP to the next level and to the next stage, where it came from.
private struct FriendDetailSheet: View {
    let friendID: UUID
    @ObservedObject private var friends = FriendStore.shared
    @AppStorage("companion") private var companionRaw = ""
    @Environment(\.dismiss) private var dismiss

    private var friend: OwnedFriend? { friends.friends.first { $0.id == friendID } }

    var body: some View {
        if let friend, let species = friend.character {
            let growth = friend.growth
            let floating = companionRaw == friend.species
            ScrollView {
                VStack(spacing: 14) {
                    SpeciesPortrait(species: species).scaleEffect(friend.stage.scale).frame(height: 150)
                    Text(species.name).font(.title2.weight(.semibold))
                    Text(FriendDetailSheet.origin(of: friend)).font(.footnote).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("LV.\(growth.level)").font(.system(.headline, design: .monospaced))
                            Text(friend.stage == .bloom ? "🌼 만개" : friend.stage.title).font(.subheadline).foregroundStyle(Palette.moss)
                            Spacer()
                            Text("\(growth.progress) / 100 EXP").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(growth.progress), total: 100).tint(Palette.sage)
                        Text("다음 레벨까지 \(100 - growth.progress) EXP").font(.caption).foregroundStyle(.secondary)
                        if let left = FriendGrowth.toNextStage(xp: friend.xp) {
                            Text("\(friend.stage == .baby ? "성장기" : "만개")까지 \(left) EXP").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("만개했어요. 교배 부모가 될 수 있어요.").font(.caption).foregroundStyle(Palette.moss)
                        }
                        Text("함께 찍은 사진 \(friend.photos ?? 0)장 · 모은 EXP \(friend.xp)").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                    Button {
                        companionRaw = floating ? "" : friend.species
                        dismiss()
                    } label: {
                        Text(floating ? "기본 모리로 돌아가기" : "카메라에 띄우기")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Palette.moss, in: Capsule()).foregroundStyle(.white)
                    }
                    Text("떠 있는 동안 찍은 사진의 EXP는 이 친구만 받아요.").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(22)
            }
            .background(Palette.cream)
            .foregroundStyle(Palette.ink)
        }
    }

    static func origin(of friend: OwnedFriend) -> String {
        let since = friend.since.formatted(date: .abbreviated, time: .omitted)
        let place = friend.origin.map { "\($0) · " } ?? ""
        switch friend.how {
        case .starter: return "\(place)첫 친구 · \(since)"
        case .adopted: return "\(place)유리병으로 온 친구 · \(since)"
        case .sea: return "바다에서 온 친구 · \(since)"
        case .event: return "계절 친구 · \(since)"
        case .explored: return "\(place)탐험에서 만난 친구 · \(since)"
        }
    }
}
