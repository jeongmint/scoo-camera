import SwiftUI

extension TalkPet {
    var color: Color { Color(red: tint.red, green: tint.green, blue: tint.blue) }
}

/// The frame of the camera glowing softly in the friend's color, with little equalizer bars along all four
/// edges that move with the voice: the microphone while listening, the friend while it speaks, a slow
/// breath while it thinks.
struct TalkGlow: View {
    let color: Color
    let level: Double
    let phase: PetTalkSession.Phase

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let energy = energy(at: time)
                let corner: CGFloat = 46
                let frame = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
                let edge = Path(roundedRect: frame, cornerRadius: corner, style: .continuous)

                // soft colored glow hugging the frame
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 16 + 14 * energy))
                    layer.stroke(edge, with: .color(color.opacity(0.30 + 0.40 * energy)), lineWidth: 14 + 30 * energy)
                }
                context.stroke(edge, with: .color(color.opacity(0.35 + 0.45 * energy)), lineWidth: 1.5 + 2 * energy)

                // equalizer bars pointing inward from each edge
                let spacing: CGFloat = 15
                let inset: CGFloat = corner * 0.75
                var bars = Path()
                var index = 0
                func bar(at point: CGPoint, inward: CGVector) {
                    let wave = 0.30 + 0.70 * abs(sin(time * 6.1 + Double(index) * 0.83) * cos(time * 3.3 + Double(index) * 0.29))
                    let length = 3 + CGFloat(26 * energy * wave)
                    bars.move(to: CGPoint(x: point.x + inward.dx * 5, y: point.y + inward.dy * 5))
                    bars.addLine(to: CGPoint(x: point.x + inward.dx * (5 + length), y: point.y + inward.dy * (5 + length)))
                    index += 1
                }
                var x = inset
                while x <= size.width - inset {
                    bar(at: CGPoint(x: x, y: 0), inward: CGVector(dx: 0, dy: 1))
                    bar(at: CGPoint(x: size.width - x, y: size.height), inward: CGVector(dx: 0, dy: -1))
                    x += spacing
                }
                var y = inset
                while y <= size.height - inset {
                    bar(at: CGPoint(x: 0, y: y), inward: CGVector(dx: 1, dy: 0))
                    bar(at: CGPoint(x: size.width, y: size.height - y), inward: CGVector(dx: -1, dy: 0))
                    y += spacing
                }
                context.stroke(bars, with: .color(color.opacity(0.55 + 0.4 * energy)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func energy(at time: TimeInterval) -> Double {
        switch phase {
        case .off: return 0
        case .starting: return 0.12
        case .thinking: return 0.22 + 0.14 * (0.5 + 0.5 * sin(time * 3.2))
        case .listening, .speaking: return min(1, max(0.08, level))
        }
    }
}

/// What was heard and what the friend says back, in a small bubble above the friend.
struct TalkBubble: View {
    let name: String
    let phase: PetTalkSession.Phase
    let heard: String
    let reply: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch phase {
            case .off, .starting:
                Label("마이크 켜는 중…", systemImage: "mic").font(.system(size: 12, weight: .medium))
            case .listening:
                if heard.isEmpty {
                    Label("듣고 있어요. 말해 보세요!", systemImage: "mic.fill").font(.system(size: 12, weight: .medium))
                } else {
                    Text(heard).font(.system(size: 13, weight: .medium))
                }
            case .thinking:
                if !heard.isEmpty { Text(heard).font(.system(size: 11)).opacity(0.7).lineLimit(2) }
                ThinkingDots(color: color)
            case .speaking:
                Text(reply).font(.system(size: 15, weight: .semibold))
            }
        }
        .multilineTextAlignment(.leading)
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: 250, alignment: .leading)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.8), lineWidth: 1.5))
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeOut(duration: 0.2), value: phase)
        .accessibilityElement(children: .combine)
    }
}

private struct ThinkingDots: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle().fill(color)
                        .frame(width: 7, height: 7)
                        .offset(y: -4 * max(0, sin(time * 6 - Double(index) * 0.8)))
                }
            }
            .frame(height: 14)
        }
        .accessibilityLabel("생각하는 중")
    }
}

/// Friends nearby on the camera: each friend floats toward where they are, on a ring inside the frame,
/// with how far away they are. Friends behind the phone sit at the bottom edge.
struct RadarOverlay: View {
    let blips: [FriendRadar.Blip]
    let heading: Double
    let size: CGSize
    let insets: EdgeInsets

    var body: some View {
        let center = CGPoint(x: size.width / 2, y: (insets.top + 120 + size.height - insets.bottom - 150) / 2)
        let rx = size.width / 2 - 58
        let ry = (size.height - insets.top - insets.bottom - 300) / 2
        ZStack {
            ForEach(blips.prefix(6)) { blip in
                let turn = (blip.bearing - heading) * .pi / 180
                let point = CGPoint(x: center.x + CGFloat(sin(turn)) * rx, y: center.y - CGFloat(cos(turn)) * ry)
                chip(blip, turn: turn).position(point)
            }
        }
        .animation(.easeOut(duration: 0.4), value: heading)
        .allowsHitTesting(false)
    }

    private func chip(_ blip: FriendRadar.Blip, turn: Double) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "location.north.fill").font(.system(size: 9))
                .rotationEffect(.radians(turn))
            if let species = blip.hero.flatMap(Species.find) {
                SpeciesPortrait(species: species).frame(width: 22, height: 22)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(blip.name).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                Text(FriendRadar.label(blip.meters)).font(.system(size: 9, design: .monospaced))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(.black.opacity(0.5), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(blip.name), \(FriendRadar.label(blip.meters))")
    }
}
