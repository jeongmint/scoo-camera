import SwiftUI
import UIKit
import WidgetKit

/// Keeps the home-screen widget up to date: writes a small snapshot and three small PNGs into the app group,
/// then asks WidgetKit to reload. Does nothing if the App Groups capability is not set up yet.
@MainActor
enum WidgetBridge {
    private static var lastGarden: GardenSnapshot?
    private static let imageSide: CGFloat = 300

    /// Call whenever the garden changes.
    static func publish(_ garden: GardenSnapshot) {
        lastGarden = garden
        refresh()
    }

    /// The floating one's picture: a bred baby's portrait, a friend, or Mori.
    @ViewBuilder
    private static func hero(picked: Species?, baby: Breed?, moments: Int) -> some View {
        if let baby {
            BreedPortrait(breed: baby, stage: baby.stage(moments: moments))
        } else {
            Image(picked?.assetName ?? "Companion-mori").resizable().scaledToFit()
        }
    }

    /// The picked friend's own EXP, read straight from storage (FriendStore calls `refresh` while it starts up).
    private static func ownXP(_ species: Species) -> Int? {
        struct Saved: Decodable { let friends: [OwnedFriend] }
        guard let data = UserDefaults.standard.data(forKey: FriendStore.key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return nil }
        return saved.friends.first { $0.species == species.id }?.xp
    }

    /// Call when something outside the garden changes (the user's friend, a new baby).
    static func refresh() {
        guard let garden = lastGarden else { return }
        // The walk Live Activity counts photos since it started; it works even without the app group.
        if let started = WalkMode.startedAt {
            WalkMode.update(photos: garden.photos.filter { $0.date >= started }.count)
        }
        guard WidgetShared.container != nil else { return }
        let calendar = Calendar.current
        let friend = Species.find(UserDefaults.standard.string(forKey: "assignedCompanion") ?? "")
        // The character picked in 같이 찍기 floats in Mori's place in the app, so it leads the widget too.
        // (FriendStore clears the pick when that character leaves.)
        let raw = UserDefaults.standard.string(forKey: "companion") ?? ""
        let picked = Species.find(raw)
        // A floating bred baby leads the widget too.
        let floatingBaby: Breed? = Floater.babyID(raw).flatMap { id in
            let babies = BreedStore()
            babies.load()
            return babies.breeds.first { $0.id == id }
        }
        // Everyone grows by themselves; 기본 모리 keeps the garden's EXP.
        let growth = GrowthRules.growth(for: floatingBaby?.xp(moments: garden.moments) ?? picked.flatMap(ownXP) ?? garden.experience)
        let sidekick = picked == friend ? nil : friend
        let baby = latestBaby()
        let snapshot = WidgetSnapshot(
            name: floatingBaby.map { "아기 \($0.title)" } ?? picked?.name ?? garden.name, level: growth.level, progress: growth.progress, moments: garden.moments,
            todayCount: garden.photos.filter { calendar.isDateInToday($0.date) }.count,
            today: calendar.startOfDay(for: Date()),
            friendName: sidekick?.name,
            baby: baby.map { WidgetSnapshot.Baby(title: $0.title, photosLeft: $0.photosLeft(moments: garden.moments),
                                                  adult: $0.isAdult(moments: garden.moments)) },
            updated: Date())
        writeImage(hero(picked: picked, baby: floatingBaby, moments: garden.moments), as: "hero")
        // Live Activities only take tiny images.
        writeImage(hero(picked: picked, baby: floatingBaby, moments: garden.moments), as: "hero-small", side: 64)
        if let sidekick { writeImage(Image(sidekick.assetName).resizable().scaledToFit(), as: "friend") }
        if let baby { writeImage(BreedPortrait(breed: baby, adult: baby.isAdult(moments: garden.moments)), as: "baby") }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func latestBaby() -> Breed? {
        let url = PhotoRepository.directory.appendingPathComponent("breeds.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode([Breed].self, from: data))?.first
    }

    /// Widgets must stay small in memory, so images are rendered at a fixed small size.
    private static func writeImage<Content: View>(_ content: Content, as name: String, side: CGFloat = imageSide) {
        guard let url = WidgetShared.imageURL(name) else { return }
        let renderer = ImageRenderer(content: content.frame(width: side, height: side))
        renderer.scale = 1
        renderer.isOpaque = false
        guard let data = renderer.uiImage?.pngData() else { return }
        try? data.write(to: url, options: .atomic)
    }
}
