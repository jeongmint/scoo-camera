import SwiftUI
import UIKit

/// 유리병 입양: once a day, send one of my characters or babies off. The next day either someone else's bottle
/// comes back (adoption), or, if nobody came, the sea brings a new character. Letters come from those that left.
/// With the server configured the other side is real people; otherwise it is simulated on this device (`LocalOcean`).
struct BottleScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @StateObject private var breeds = BreedStore()
    @StateObject private var bottles = BottleStore.preferred()
    @ObservedObject private var friends = FriendStore.shared
    @StateObject private var locator = DistrictLocator()
    /// Where the user is now: a bottle sent from here brings this place's friends if nobody swaps.
    @State private var here: Region?
    @AppStorage("bottleFastMode") private var fast = false
    @AppStorage("district") private var districtRaw = ""
    /// A character (OwnedFriend id) or a baby (Breed id).
    @State private var picked: UUID?
    @State private var wantsNews = true
    @State private var drifting = false
    @State private var gift: BottleGift?
    @State private var error: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let now = context.date
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("하루에 한 번, 친구나 아기 하나를 유리병에 담아 띄워요. 다음 날 누군가의 유리병이 떠내려오거나, 아무도 없으면 바다에서 새 친구가 와요. 보낸 아이는 가끔 편지를 보내요.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Label(bottles.isOnline ? "진짜 사람들과 주고받는 중" : "이 기기 안에서 시험하는 중",
                          systemImage: bottles.isOnline ? "globe.asia.australia" : "iphone")
                        .font(.caption2).foregroundStyle(Palette.sage)
                    fromSea(now)
                    arrived(now)
                    send(now)
                    traveling(now)
                    letters(now)
                }
                .padding(22)
            }
            .refreshable { await bottles.load() }
        }
        .background(Palette.cream)
        .foregroundStyle(Palette.ink)
        .navigationTitle("유리병 입양")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { breeds.load() }
        .task {
            if let spot = await locator.quickLocation() { here = await locator.region(at: spot) }
            await bottles.load()
            await settle()
            // Online, bottles can be matched by other people at any time: look again every half minute.
            while bottles.isOnline && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await bottles.load()
                await settle()
            }
        }
        .overlay { if drifting { DriftingBottle().transition(.opacity) } }
        .sheet(item: $gift) { gift in AdoptedSheet(gift: gift) }
        .alert("유리병", isPresented: Binding(get: { error != nil || bottles.message != nil },
                                           set: { if !$0 { error = nil; bottles.message = nil } })) {
            Button("확인", role: .cancel) { }
        } message: { Text(error ?? bottles.message ?? "") }
    }

    // MARK: Arrived

    @ViewBuilder
    private func arrived(_ now: Date) -> some View {
        let ready = bottles.bottles.filter { $0.direction == .incoming && $0.hasArrived(at: now) && !$0.opened }
        if !ready.isEmpty {
            section("도착한 유리병") {
                ForEach(ready) { bottle in
                    HStack(spacing: 14) {
                        BottleGlyph().frame(width: 34, height: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(bottle.origin)에서 온 유리병").font(.subheadline.weight(.medium))
                            Text("안에서 무언가 꼼지락거려요").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("열어보기") { open(bottle) }
                            .disabled(bottles.busy)
                            .font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Palette.moss, in: Capsule()).foregroundStyle(.white)
                    }
                    .padding(14)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func open(_ bottle: Bottle) {
        Task {
            do {
                gift = try await bottles.open(bottle, breeds: breeds, friends: friends, moments: garden.snapshot.moments)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: From the sea

    /// Characters the sea brought in the last three days (bottles nobody came for).
    @ViewBuilder
    private func fromSea(_ now: Date) -> some View {
        let recent = friends.friends.filter { $0.how == .sea && now.timeIntervalSince($0.since) < 3 * 86_400 }
        if !recent.isEmpty {
            section("바다에서 온 친구") {
                ForEach(recent) { friend in
                    HStack(spacing: 14) {
                        if let species = friend.character { SpeciesPortrait(species: species).frame(width: 52, height: 52) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(friend.character?.name ?? "새 친구").font(.subheadline.weight(.medium))
                            Text("띄운 유리병의 짝이 없어서 바다가 새 친구를 데려왔어요").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func settle() async {
        let came = await bottles.settleWaiting(home: Regions.resolve(districtRaw), friends: friends, fast: fast)
        if let first = came.first {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            gift = .character(first)
        }
    }

    // MARK: Send

    private func send(_ now: Date) -> some View {
        let allowed = bottles.canSend(now: now, fast: fast)
        let travellers = friends.friends.filter(\.canTravel)
        let canPart = BottleStore.canPart(friends: friends.friends.count, babies: breeds.breeds.count)
        return section("유리병 띄우기") {
            if travellers.isEmpty && breeds.breeds.isEmpty {
                Text("띄울 친구가 없어요.").font(.footnote).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(travellers) { friend in
                            choice(id: friend.id, title: friend.character?.name ?? friend.species, note: "친구") {
                                if let species = friend.character { SpeciesPortrait(species: species) }
                            }
                        }
                        ForEach(breeds.breeds) { baby in
                            choice(id: baby.id, title: baby.title, note: "아기") {
                                BreedPortrait(breed: baby, stage: baby.stage(moments: garden.snapshot.moments))
                            }
                        }
                    }
                }
                if let place = here ?? Regions.resolve(districtRaw) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(place.title)에서 띄워요 · 짝이 없으면 이 동네 친구 중 하나가 와요").font(.caption)
                        HStack(spacing: 6) {
                            ForEach(place.candidateSpecies) { species in
                                SpeciesPortrait(species: species).frame(width: 30, height: 30)
                                    .opacity(friends.owns(species.id) ? 0.4 : 1)
                            }
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                Toggle("가끔 소식 전해줘", isOn: $wantsNews).font(.subheadline).tint(Palette.moss)
                Button { sendPicked(now) } label: {
                    Label("유리병에 담아 띄우기", systemImage: "water.waves").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(picked != nil && allowed && canPart ? Palette.moss : Palette.sage.opacity(0.35), in: Capsule())
                        .foregroundStyle(.white)
                }
                .disabled(picked == nil || !allowed || !canPart || bottles.busy)
                Text(!canPart ? "마지막 한 마리는 보낼 수 없어요. 친구가 둘 이상일 때 띄울 수 있어요."
                     : allowed ? "띄운 아이는 내 목록에서 떠나요. 되돌릴 수 없어요. 내일 답이 와요."
                     : "오늘은 이미 유리병을 띄웠어요. 내일 또 띄울 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func choice<Picture: View>(id: UUID, title: String, note: String, @ViewBuilder picture: () -> Picture) -> some View {
        let chosen = picked == id
        return Button { picked = id } label: {
            VStack(spacing: 4) {
                picture().frame(width: 74, height: 74)
                Text(title).font(.system(size: 10)).lineLimit(1).frame(width: 84)
                Text(note).font(.system(size: 8)).foregroundStyle(.secondary)
            }
            .padding(8)
            .background(chosen ? Palette.sage.opacity(0.25) : .white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func sendPicked(_ now: Date) {
        guard let id = picked else { return }
        Task {
            do {
                let from = here?.id ?? (districtRaw.isEmpty ? nil : districtRaw)
                if let friend = friends.friends.first(where: { $0.id == id }) {
                    try await bottles.send(friend, wantsNews: wantsNews, from: from, friends: friends, babies: breeds.breeds.count,
                                           fast: fast, now: now)
                } else if let baby = breeds.breeds.first(where: { $0.id == id }) {
                    try await bottles.send(baby, wantsNews: wantsNews, from: from, breeds: breeds, friends: friends.friends.count,
                                           fast: fast, now: now)
                } else { return }
                picked = nil
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation { drifting = true }
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation { drifting = false }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: Traveling

    @ViewBuilder
    private func traveling(_ now: Date) -> some View {
        let moving = bottles.bottles.filter { !$0.hasArrived(at: now) }
        if !moving.isEmpty {
            section("바다 위의 유리병") {
                ForEach(moving) { bottle in
                    HStack(spacing: 12) {
                        BottleGlyph().frame(width: 22, height: 34).opacity(0.7)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bottle.direction == .outgoing ? "\(bottle.title) · 가는 중" : "어딘가에서 떠내려오는 중")
                                .font(.subheadline)
                            if bottle.isWaitingAtSea {
                                Text(bottle.settled == true ? "새 가족을 찾는 중 · 답은 이미 받았어요"
                                     : "바다에서 짝을 기다리는 중 · 내일까지 짝이 없으면 바다에서 새 친구가 와요")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                HStack(spacing: 3) {
                                    Text(bottle.arrivesAt, style: .relative)
                                    Text("뒤 도착")
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Letters

    @ViewBuilder
    private func letters(_ now: Date) -> some View {
        let all = BottleRules.letters(for: bottles.bottles, now: now, fast: fast, moments: bottles.moments)
        let sent = bottles.bottles.filter { $0.direction == .outgoing && $0.hasArrived(at: now) }
        if !all.isEmpty || !sent.isEmpty {
            section("입양 간 아이들의 소식") {
                if all.isEmpty {
                    Text("도착했다는 소식이 곧 올 거예요.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(all) { letter in
                    HStack(alignment: .top, spacing: 12) {
                        BottleFace(bottle: letter.bottle).frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(letter.text).font(.subheadline)
                            Text("\(letter.bottle.title) · \(letter.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
    }
}

// MARK: - Pieces

/// A little glass bottle with a cork.
private struct BottleGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: w * 0.35)
                    .fill(LinearGradient(colors: [Color(red: 0.78, green: 0.9, blue: 0.88).opacity(0.9), Color(red: 0.6, green: 0.78, blue: 0.8).opacity(0.8)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { RoundedRectangle(cornerRadius: w * 0.35).stroke(.white.opacity(0.8), lineWidth: 1) }
                    .frame(width: w, height: h * 0.72)
                    .offset(y: h * 0.28)
                RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.7, green: 0.85, blue: 0.84).opacity(0.9))
                    .frame(width: w * 0.42, height: h * 0.2).offset(y: h * 0.1)
                RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.72, green: 0.55, blue: 0.38))
                    .frame(width: w * 0.36, height: h * 0.12)
            }
            .frame(width: w, height: h)
        }
        .accessibilityHidden(true)
    }
}

/// The bottle bobbing off to sea after it is sent.
private struct DriftingBottle: View {
    @State private var away = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 14) {
                BottleGlyph().frame(width: 60, height: 92)
                    .rotationEffect(.degrees(away ? 24 : -8))
                    .offset(x: away ? 260 : 0, y: away ? -30 : 0)
                    .opacity(away ? 0 : 1)
                Image(systemName: "water.waves").font(.largeTitle).foregroundStyle(Palette.sage)
                Text("둥실둥실, 잘 다녀와!").font(.subheadline.weight(.medium))
            }
            .padding(30)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 24))
        }
        .onAppear { withAnimation(.easeIn(duration: 1.5)) { away = true } }
    }
}

private struct AdoptedSheet: View {
    let gift: BottleGift
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 16) {
            switch gift {
            case .baby(let baby):
                BreedPortrait(breed: baby).frame(width: 220, height: 220)
                Text("\(baby.origin ?? "어딘가")에서 온 아이").font(.title3.weight(.semibold))
                Text(baby.title).font(.subheadline).foregroundStyle(.secondary)
                Text("우리 아기들에 들어왔어요. 사진을 \(BreedRules.photosToGrowing)장 찍으면 성장, \(BreedRules.photosToGrow)장이면 데이지를 단 만개가 돼요.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .character(let species):
                SpeciesPortrait(species: species).frame(width: 220, height: 220)
                Text("새 친구, \(species.name)").font(.title3.weight(.semibold))
                Text("내 친구가 됐어요. 카메라에 띄우거나 교배할 때 부모로 고를 수 있어요.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button("반가워!") { dismiss() }
                .font(.headline).padding(.horizontal, 36).padding(.vertical, 12)
                .background(Palette.moss, in: Capsule()).foregroundStyle(.white)
        }
        .padding(28)
        .foregroundStyle(Palette.ink)
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.cream)
    }
}

/// The one inside a bottle: a character, or a bred baby.
struct BottleFace: View {
    let bottle: Bottle
    var body: some View {
        if let species = bottle.character { SpeciesPortrait(species: species) } else { BreedPortrait(breed: bottle.baby) }
    }
}
