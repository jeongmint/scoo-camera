import Foundation

/// Faces the floating friend makes around a shot:
/// 평소 미소 → 찰칵(눈감기) → 사진에 맞는 반응 → 평소 미소.
enum MoriExpression: String, CaseIterable, Equatable {
    case normal     // 평소 미소
    case shutter    // 찰칵: eyes closed while the photo is taken
    case surprised  // 깜짝
    case smile      // 방긋
    case awe        // 감탄
    case yum        // 냠냠

    /// Light/detail bonus (0...10) from which a photo counts as 감탄. Provisional until the real criteria are decided.
    static let aweBonus = 8

    /// Picks the reaction once the photo has been looked at.
    /// Food is always 냠냠, a level-up is always 방긋, a high light/detail score is 감탄.
    /// Everything else varies between 방긋 and 깜짝 and never repeats the previous face.
    /// `roll` is a random number in 0..<1 (injected so the choice can be tested).
    static func reaction(isFood: Bool, bonus: Int, leveledUp: Bool, previous: MoriExpression?, roll: Double) -> MoriExpression {
        if isFood { return .yum }
        if leveledUp { return .smile }
        if bonus >= aweBonus { return .awe }
        let pool: [MoriExpression] = [.smile, .surprised]
        let index = min(pool.count - 1, max(0, Int(roll * Double(pool.count))))
        let pick = pool[index]
        return pick == previous ? pool[(index + 1) % pool.count] : pick
    }
}
