import SwiftUI
import MultipeerConnectivity
import UIKit

/// 근처에서 바로 친구 추가: like AirDrop, phones that have this screen open at the same time find each other
/// over Bluetooth / Wi-Fi without the internet, and show each other's name and friend code.
/// Nothing is shared while the screen is closed.
@MainActor
final class NearbyFinder: NSObject, ObservableObject {
    struct Person: Identifiable, Equatable {
        let id: String
        let name: String
        let code: String
    }

    @Published private(set) var people: [Person] = []
    static let service = "scoo-friend"

    private var me: MCPeerID?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    func start(name: String, code: String) {
        stop()
        let peer = MCPeerID(displayName: String(name.prefix(30)))
        me = peer
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: ["code": code, "name": String(name.prefix(30))],
                                               serviceType: Self.service)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.service)
        advertiser?.delegate = self
        browser?.delegate = self
        advertiser?.startAdvertisingPeer()
        browser?.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        people = []
    }

    fileprivate func found(_ id: String, info: [String: String]?) {
        guard let code = info?["code"], code.count == 6 else { return }
        let person = Person(id: id, name: info?["name"] ?? "스쿠 친구", code: code)
        people.removeAll { $0.id == id }
        people.append(person)
    }

    fileprivate func lost(_ id: String) { people.removeAll { $0.id == id } }
}

extension NearbyFinder: MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let id = "\(peerID.displayName)#\(peerID.hash)"
        Task { @MainActor in self.found(id, info: info) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let id = "\(peerID.displayName)#\(peerID.hash)"
        Task { @MainActor in self.lost(id) }
    }

    /// Nobody connects: the code in the discovery info is all that is needed.
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(false, nil)
    }
}

/// The screen: shows people nearby with this screen open; one tap sends a friend request.
struct NearbyAddScreen: View {
    @ObservedObject var social: SocialStore
    @StateObject private var finder = NearbyFinder()
    @Environment(\.dismiss) private var dismiss
    @State private var note: String?
    @State private var asked: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("친구도 이 화면을 열어 두면 서로 보여요. 인터넷 없이 블루투스·와이파이로 찾아요.", systemImage: "dot.radiowaves.left.and.right")
                        .font(.footnote)
                    if let code = social.profile?.friend_code {
                        LabeledContent("내 친구 코드", value: code)
                    }
                }
                Section("근처에 있는 사람") {
                    if finder.people.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("찾는 중…").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(finder.people) { person in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                Text(person.code).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(asked.contains(person.code) ? "보냄" : "친구 신청") {
                                Task {
                                    note = await social.add(code: person.code)
                                    asked.insert(person.code)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(asked.contains(person.code))
                        }
                    }
                }
                if let note { Section { Text(note).font(.footnote) } }
            }
            .scrollContentBackground(.hidden).background(Palette.cream)
            .navigationTitle("근처에서 친구 추가").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .task {
                if social.profile == nil { await social.refresh() }
                guard let code = social.profile?.friend_code else {
                    note = "서버에 연결하면 친구 코드가 생겨요."
                    return
                }
                finder.start(name: social.profile?.nickname ?? "스쿠 친구", code: code)
            }
            .onDisappear { finder.stop() }
        }
        .tint(Palette.moss)
    }
}
