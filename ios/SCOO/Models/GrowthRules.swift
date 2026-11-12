import Foundation

enum CaptureMode: String, CaseIterable, Codable, Identifiable {
    case auto, daily, food
    var id: String { rawValue }
    var title: String { switch self { case .auto: "자동"; case .daily: "일상"; case .food: "음식" } }
}

struct Growth: Equatable {
    let level: Int
    let progress: Int
    let size: Double
}

enum GrowthRules {
    static func growth(for experience: Int) -> Growth {
        let xp = max(0, experience)
        return Growth(level: 1 + xp / 100, progress: xp % 100, size: 1 + sqrt(Double(xp)) * 0.065)
    }

    static func reward(isFood: Bool, bonus: Int) -> Int {
        (isFood ? 20 : 12) + min(10, max(0, bonus))
    }

    /// A technical proxy for light and local detail, not an aesthetic judgement.
    static func qualityBonus(luminance: [Double], width: Int, height: Int) -> Int {
        guard width > 1, height > 1, luminance.count == width * height else { return 0 }
        let count = Double(luminance.count)
        let average = luminance.reduce(0, +) / count
        let variance = luminance.reduce(0) { $0 + pow($1 - average, 2) } / count
        var edges = 0.0
        for y in 1..<height {
            for x in 1..<width {
                let index = y * width + x
                edges += abs(luminance[index] - luminance[index - 1])
                edges += abs(luminance[index] - luminance[index - width])
            }
        }
        let light = max(0, 1 - abs(average - 132) / 115)
        let detail = min(1, sqrt(variance) / 55) * 0.5
            + min(1, edges / (Double((width - 1) * (height - 1)) * 35)) * 0.5
        return min(10, max(0, Int((light * 5 + detail * 5).rounded())))
    }
}
