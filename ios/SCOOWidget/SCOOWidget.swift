import WidgetKit
import SwiftUI
import AppIntents
import UIKit
import ActivityKit

// MARK: - Timeline

struct SCOOEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let petted: Bool
}

struct SCOOProvider: TimelineProvider {
    func placeholder(in context: Context) -> SCOOEntry {
        SCOOEntry(date: Date(), snapshot: .placeholder, petted: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SCOOEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SCOOEntry>) -> Void) {
        let now = Date()
        let first = entry(at: now)
        var entries = [first]
        // After a pet, calm down again a few seconds later.
        if first.petted, let pettedAt = WidgetShared.defaults?.object(forKey: WidgetShared.pettedKey) as? Date {
            entries.append(SCOOEntry(date: pettedAt.addingTimeInterval(WidgetShared.happySeconds), snapshot: first.snapshot, petted: false))
        }
        // The app reloads the widget after every photo; on our own we only need to reset "today" after midnight.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: entries, policy: .after(tomorrow.addingTimeInterval(60))))
    }

    private func entry(at date: Date) -> SCOOEntry {
        let petted = (WidgetShared.defaults?.object(forKey: WidgetShared.pettedKey) as? Date)
            .map { date.timeIntervalSince($0) < WidgetShared.happySeconds } ?? false
        return SCOOEntry(date: date, snapshot: WidgetSnapshot.load() ?? .placeholder, petted: petted)
    }
}

// MARK: - Pet

/// Tapping the character in the widget pets it. Runs in the widget; the widget reloads afterwards.
struct PetIntent: AppIntent {
    static var title: LocalizedStringResource = "쓰다듬기"
    static var description: IntentDescription? = IntentDescription("위젯의 친구를 쓰다듬어요.")

    func perform() async throws -> some IntentResult {
        WidgetShared.defaults?.set(Date(), forKey: WidgetShared.pettedKey)
        return .result()
    }
}

// MARK: - Views

private enum Ink {
    static let cream = Color(red: 0.95, green: 0.95, blue: 0.91)
    static let ink = Color(red: 0.16, green: 0.24, blue: 0.18)
    static let sage = Color(red: 0.52, green: 0.62, blue: 0.43)
}

/// A PNG the app rendered into the app group, or a leaf while there is none yet.
private struct SharedImage: View {
    let name: String
    var body: some View {
        if let url = WidgetShared.imageURL(name), let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "leaf.circle.fill").resizable().scaledToFit().foregroundStyle(Ink.sage)
        }
    }
}

struct SCOOWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SCOOEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var today: Int { snapshot.photosToday(at: entry.date) }
    private var line: String {
        if entry.petted { return "보송보송, 기분 좋아!" }
        if today == 0 { return "오늘의 첫 순간 기다려" }
        return "오늘 \(today)장 먹었어"
    }

    var body: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: small
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(snapshot.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 0)
            Text("LV.\(snapshot.level)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Ink.sage)
        }
    }

    private var pettable: some View {
        Button(intent: PetIntent()) {
            SharedImage(name: "hero")
                .scaleEffect(entry.petted ? 1.08 : 1)
                .rotationEffect(.degrees(entry.petted ? -6 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(snapshot.name) 쓰다듬기")
    }

    private var progress: some View {
        ProgressView(value: Double(snapshot.progress), total: 100).tint(Ink.sage)
    }

    private var small: some View {
        VStack(spacing: 6) {
            header
            pettable.frame(maxHeight: .infinity)
            Text(line).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
            progress
        }
        .foregroundStyle(Ink.ink)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            small
            VStack(alignment: .leading, spacing: 8) {
                if let friend = snapshot.friendName {
                    HStack(spacing: 8) {
                        SharedImage(name: "friend").frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("함께하는 친구").font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(friend).font(.system(size: 12, weight: .medium))
                        }
                    }
                }
                if let baby = snapshot.baby {
                    HStack(spacing: 8) {
                        SharedImage(name: "baby").frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(baby.adult ? "성체가 됐어요" : "아기 · 사진 \(baby.photosLeft)장 더").font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(baby.title).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                }
                Spacer(minLength: 0)
                Text("먹은 순간 \(snapshot.moments)컷").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Ink.ink)
        }
    }

    private var circular: some View {
        Gauge(value: Double(snapshot.progress), in: 0...100) {
            Text("LV")
        } currentValueLabel: {
            Text("\(snapshot.level)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityLabel("\(snapshot.name) 레벨 \(snapshot.level)")
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(snapshot.name) · LV.\(snapshot.level)").font(.headline).widgetAccentable()
            Text(line).font(.caption)
            if let baby = snapshot.baby, !baby.adult {
                Text("아기 · 사진 \(baby.photosLeft)장 더").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct SCOOWidget: Widget {
    let kind = "SCOOWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SCOOProvider()) { entry in
            SCOOWidgetView(entry: entry)
                .containerBackground(for: .widget) { Ink.cream }
        }
        .configurationDisplayName("스쿠 친구")
        .description("모리의 레벨과 오늘 먹은 순간, 함께하는 친구와 아기를 보여줘요. 모리를 누르면 쓰다듬어요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - 산책 모드 (Live Activity)

struct WalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkAttributes.self) { context in
            HStack(spacing: 14) {
                SharedImage(name: "hero-small").frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(context.attributes.heroName)랑 산책 중").font(.headline)
                    Text(walkLine(context.state)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
            }
            .padding(16)
            .foregroundStyle(Ink.ink)
            .activityBackgroundTint(Ink.cream)
            .activitySystemActionForegroundColor(Ink.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SharedImage(name: "hero-small").frame(width: 40, height: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.photos)장").font(.title3.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("\(context.attributes.heroName)랑 산책 중 · \(context.state.district ?? "어디로 갈까")").font(.caption)
                        Spacer()
                        Text(context.attributes.startedAt, style: .timer).font(.caption.monospacedDigit()).frame(width: 56)
                    }
                }
            } compactLeading: {
                SharedImage(name: "hero-small").frame(width: 22, height: 22)
            } compactTrailing: {
                Text("\(context.state.photos)장").font(.caption2.weight(.semibold))
            } minimal: {
                SharedImage(name: "hero-small").frame(width: 20, height: 20)
            }
        }
    }

    private func walkLine(_ state: WalkAttributes.ContentState) -> String {
        let place = state.district.map { "\($0) · " } ?? ""
        return state.photos == 0 ? "\(place)첫 순간을 찾는 중" : "\(place)\(state.photos)장 찍었어"
    }
}

@main
struct SCOOWidgetBundle: WidgetBundle {
    var body: some Widget {
        SCOOWidget()
        WalkLiveActivity()
    }
}
