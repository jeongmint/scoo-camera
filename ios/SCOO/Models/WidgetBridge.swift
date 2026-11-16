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

    /// Call when something outside the garden changes (the user's friend, a new baby).
    static func refresh() {
        guard let garden = lastGarden, WidgetShared.container != nil else { return }
        let growth = GrowthRules.growth(for: garden.experience)
        let calendar = Calendar.current
        let friend = Companion(rawValue: UserDefaults.standard.string(forKey: "assignedCompanion") ?? "")
        let baby = latestBaby()
        let snapshot = WidgetSnapshot(
            name: garden.name, level: growth.level, progress: growth.progress, moments: garden.moments,
            todayCount: garden.photos.filter { calendar.isDateInToday($0.date) }.count,
            today: calendar.startOfDay(for: Date()),
            friendName: friend?.title,
            baby: baby.map { WidgetSnapshot.Baby(title: $0.title, photosLeft: $0.photosLeft(moments: garden.moments),
                                                  adult: $0.isAdult(moments: garden.moments)) },
            updated: Date())
        writeImage(Image("Companion-mori").resizable().scaledToFit(), as: "mori")
        if let friend { writeImage(Image(friend.assetName).resizable().scaledToFit(), as: "friend") }
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
    private static func writeImage<Content: View>(_ content: Content, as name: String) {
        guard let url = WidgetShared.imageURL(name) else { return }
        let renderer = ImageRenderer(content: content.frame(width: imageSide, height: imageSide))
        renderer.scale = 1
        renderer.isOpaque = false
        guard let data = renderer.uiImage?.pngData() else { return }
        try? data.write(to: url, options: .atomic)
    }
}
