import SwiftUI
import UIKit

/// 편지함: letters from friends, news from babies that left in bottles, and bottles waiting to be opened.
struct InboxScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @StateObject private var social = SocialStore()
    @StateObject private var bottles = BottleStore.preferred()
    @AppStorage("bottleFastMode") private var fast = false
    @AppStorage("assignedCompanion") private var assignedRaw = ""
    @AppStorage("companion") private var companionRaw = ""
    @State private var tab: Tab = .friends
    @State private var adding = false
    @State private var code = ""
    @State private var note: String?

    private enum Tab: String, CaseIterable, Identifiable {
        case friends = "친구 편지", news = "아이들 소식", gifts = "받은 선물"
        var id: String { rawValue }
    }

    /// The character floating in my camera, shown to friends next to my letters.
    private var myHero: String {
        guard let picked = Companion(rawValue: companionRaw), let assigned = Companion(rawValue: assignedRaw),
              Companion.owned(assigned: assigned).contains(picked) else { return "mori" }
        return picked.rawValue
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Picker("편지함", selection: $tab) {
                        ForEach(Tab.allCases) { tab in
                            Text(label(for: tab)).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    switch tab {
                    case .friends: friendsTab
                    case .news: newsTab(context.date)
                    case .gifts: giftsTab(context.date)
                    }
                }
                .padding(22)
            }
            .refreshable { await reload() }
        }
        .background(Palette.cream)
        .foregroundStyle(Palette.ink)
        .navigationTitle("편지함")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reload()
            await social.setHero(myHero)
            // new letters and friend requests show up without pulling
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                await reload()
            }
        }
        .alert("친구 추가", isPresented: $adding) {
            TextField("친구 코드 6자리", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
            Button("요청 보내기") { Task { note = await social.add(code: code); code = "" } }
            Button("취소", role: .cancel) { code = "" }
        } message: { Text("친구에게 받은 코드를 넣어 주세요.") }
        .alert("편지함", isPresented: Binding(get: { note != nil || social.message != nil },
                                          set: { if !$0 { note = nil; social.message = nil } })) {
            Button("확인", role: .cancel) { }
        } message: { Text(note ?? social.message ?? "") }
    }

    private func reload() async {
        await social.refresh()
        await bottles.load()
    }

    private func label(for tab: Tab) -> String {
        switch tab {
        case .friends:
            return social.unreadTotal > 0 ? "\(tab.rawValue) \(social.unreadTotal)" : tab.rawValue
        case .gifts:
            let count = bottles.bottles.filter { $0.direction == .incoming && $0.hasArrived(at: Date()) && !$0.opened }.count
            return count > 0 ? "\(tab.rawValue) \(count)" : tab.rawValue
        case .news:
            return tab.rawValue
        }
    }

    // MARK: Friends

    @ViewBuilder
    private var friendsTab: some View {
        if !social.isAvailable {
            Text("서버에 연결되면 친구와 편지를 주고받을 수 있어요.").font(.footnote).foregroundStyle(.secondary)
        } else {
            myCodeCard
            if !social.received.isEmpty {
                section("받은 친구 요청") {
                    ForEach(social.received) { friend in
                        HStack(spacing: 12) {
                            FriendFace(friend: friend).frame(width: 40, height: 40)
                            Text(friend.name).font(.subheadline)
                            Spacer()
                            Button("수락") { Task { await social.respond(friend, accept: true) } }
                                .buttonStyle(.borderedProminent)
                            Button("거절") { Task { await social.respond(friend, accept: false) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            section("친구") {
                if social.accepted.isEmpty {
                    Text("아직 친구가 없어요. 내 코드를 보내거나 친구의 코드를 넣어 보세요.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(social.accepted) { friend in
                    NavigationLink { ChatScreen(friend: friend, social: social) } label: {
                        HStack(spacing: 12) {
                            FriendFace(friend: friend, hasLetter: friend.unread > 0).frame(width: 46, height: 46)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(friend.name).font(.subheadline.weight(.medium))
                                Text(friend.preview).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if friend.unread > 0 {
                                Text("\(friend.unread)").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 3).background(Palette.moss, in: Capsule())
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                ForEach(social.sent) { friend in
                    HStack {
                        Text(friend.name).font(.subheadline)
                        Spacer()
                        Text("요청 기다리는 중").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    private var myCodeCard: some View {
        let code = social.profile?.friend_code ?? "······"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("내 친구 코드").font(.caption).foregroundStyle(.secondary)
                    Text(code).font(.system(size: 26, weight: .semibold, design: .monospaced))
                }
                Spacer()
                Button { UIPasteboard.general.string = code; note = "코드를 복사했어요." } label: { Image(systemName: "doc.on.doc") }
                    .accessibilityLabel("코드 복사")
                ShareLink(item: "스쿠카메라에서 친구 해요! 내 친구 코드: \(code)") { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("코드 공유")
            }
            Button { adding = true } label: {
                Label("친구 코드로 추가", systemImage: "person.badge.plus").frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: News from adopted babies

    @ViewBuilder
    private func newsTab(_ now: Date) -> some View {
        let letters = BottleRules.letters(for: bottles.bottles, now: now, fast: fast)
        if letters.isEmpty {
            Text("유리병으로 보낸 아이가 ‘가끔 소식 전해줘’를 켜고 떠나면 여기로 편지가 와요.").font(.footnote).foregroundStyle(.secondary)
        }
        ForEach(letters) { letter in
            HStack(alignment: .top, spacing: 12) {
                BreedPortrait(breed: letter.bottle.baby).frame(width: 46, height: 46)
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

    // MARK: Gifts

    @ViewBuilder
    private func giftsTab(_ now: Date) -> some View {
        let ready = bottles.bottles.filter { $0.direction == .incoming && $0.hasArrived(at: now) && !$0.opened }
        if ready.isEmpty {
            Text("도착한 유리병이 생기면 여기에 보여요.").font(.footnote).foregroundStyle(.secondary)
        } else {
            ForEach(ready) { bottle in
                HStack(spacing: 12) {
                    Image(systemName: "gift").font(.title3).foregroundStyle(Palette.moss)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(bottle.origin)에서 온 유리병").font(.subheadline.weight(.medium))
                        Text("유리병 입양에서 열어 볼 수 있어요").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        NavigationLink { BottleScreen() } label: {
            Label("유리병 입양으로 가기", systemImage: "water.waves").frame(maxWidth: .infinity).padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
    }
}

/// A friend's character; with an unread letter it holds an envelope.
private struct FriendFace: View {
    let friend: FriendRow
    var hasLetter = false
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let species = friend.heroSpecies {
                SpeciesPortrait(species: species)
            } else {
                Image("Companion-mori").resizable().scaledToFit()
            }
            if hasLetter {
                Image(systemName: "envelope.fill").font(.system(size: 13)).foregroundStyle(Palette.moss)
                    .padding(3).background(.white, in: Circle())
            }
        }
    }
}

// MARK: - Conversation

struct ChatScreen: View {
    let friend: FriendRow
    @ObservedObject var social: SocialStore
    @State private var letters: [ChatMessage] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if letters.isEmpty {
                            Text("\(friend.name)에게 첫 편지를 보내 보세요.").font(.footnote).foregroundStyle(.secondary).padding(.top, 40)
                        }
                        ForEach(letters) { letter in
                            Bubble(letter: letter).id(letter.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: letters.count) { _, _ in
                    if let last = letters.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            composer
        }
        .background(Palette.cream)
        .foregroundStyle(Palette.ink)
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .alert("편지", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("확인", role: .cancel) { }
        } message: { Text(error ?? "") }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(Species.all) { species in
                    Button(species.name) { send(body: nil, sticker: species.id) }
                }
            } label: {
                Image(systemName: "face.smiling").font(.title3)
            }
            .accessibilityLabel("캐릭터 스티커 보내기")
            TextField("편지 쓰기", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
            Button { send(body: draft, sticker: nil) } label: {
                Image(systemName: "paperplane.fill").font(.title3)
            }
            .disabled(sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("보내기")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .tint(Palette.moss)
    }

    private func load() async {
        do {
            letters = try await social.conversation(with: friend)
            if letters.contains(where: { !$0.mine && $0.read_at == nil }) { await social.markRead(friend) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func send(body: String?, sticker: String?) {
        let text = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        sending = true
        Task {
            defer { sending = false }
            do {
                try await social.send(to: friend, body: (text?.isEmpty ?? true) ? nil : text, sticker: sticker)
                if body != nil { draft = "" }
                await load()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

private struct Bubble: View {
    let letter: ChatMessage
    var body: some View {
        HStack {
            if letter.mine { Spacer(minLength: 50) }
            VStack(alignment: letter.mine ? .trailing : .leading, spacing: 4) {
                if let sticker = letter.sticker, let species = Species.find(sticker) {
                    SpeciesPortrait(species: species).frame(width: 96, height: 96)
                }
                if let text = letter.body {
                    Text(text).font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(letter.mine ? Palette.sage.opacity(0.35) : .white, in: RoundedRectangle(cornerRadius: 16))
                }
                Text(letter.created_at.formatted(date: .omitted, time: .shortened)).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            if !letter.mine { Spacer(minLength: 50) }
        }
    }
}
