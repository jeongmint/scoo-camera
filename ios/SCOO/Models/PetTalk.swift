import Foundation

/// Who is talking in voice talk mode (음성 대화, 티키타카): the floating friend's name, what it is, its personality,
/// its color for the glowing frame and how high its voice is.
struct TalkPet: Equatable {
    var name: String
    /// What the friend is, for the reply model ("이끼 공 마리모").
    var kind: String
    var personality: String
    /// Frame glow color, 0...1 sRGB.
    var tint: (red: Double, green: Double, blue: Double)
    /// AVSpeechUtterance pitch multiplier (0.5...2).
    var pitch: Float

    static func == (lhs: TalkPet, rhs: TalkPet) -> Bool {
        lhs.name == rhs.name && lhs.kind == rhs.kind && lhs.personality == rhs.personality && lhs.pitch == rhs.pitch
    }

    /// The default floating Mori, or the friend picked in the camera menu.
    static func of(_ companion: Companion?, moriName: String, personality: String) -> TalkPet {
        switch companion {
        case .gwiyo: return TalkPet(name: "귀요", kind: "작은 금색 방울", personality: personality, tint: (0.86, 0.68, 0.32), pitch: 1.45)
        case .kuru: return TalkPet(name: "쿠르", kind: "몽실몽실 흰 구름", personality: personality, tint: (0.58, 0.78, 0.96), pitch: 1.3)
        case .nyamo: return TalkPet(name: "냐모", kind: "통통한 치즈 고양이", personality: personality, tint: (0.96, 0.72, 0.52), pitch: 1.4)
        case .happy: return TalkPet(name: "해피", kind: "초록 목도리를 한 눈사람", personality: personality, tint: (0.62, 0.78, 0.56), pitch: 1.2)
        case .mori, nil:
            return TalkPet(name: companion == nil ? moriName : "모리", kind: "동글동글 이끼 공 마리모", personality: personality,
                    tint: (0.47, 0.66, 0.30), pitch: 1.25)
        }
    }
}

/// One exchange, sent along so the reply model remembers the last few lines.
struct TalkTurn: Equatable, Codable {
    var me: String
    var pet: String
}

/// A reply and the face the friend makes while saying it.
struct TalkReply: Equatable {
    var text: String
    var mood: MoriExpression

    init(_ text: String, _ mood: MoriExpression = .smile) {
        self.text = text
        self.mood = mood
    }

    /// The server's mood word, or a smile.
    static func mood(named name: String?) -> MoriExpression {
        switch name {
        case "surprised": return .surprised
        case "awe": return .awe
        case "yum": return .yum
        case "normal": return .normal
        default: return .smile
        }
    }
}

/// Replies made on the phone, used when the server is off, unreachable or slow. A handful of feelings is
/// recognised by keyword; anything else gets a friendly nudge. `roll` (0..<1) picks among the lines.
enum LocalReplies {
    private struct Rule {
        let words: [String]
        let lines: [String]
        let mood: MoriExpression
    }

    private static let rules: [Rule] = [
        Rule(words: ["죽고", "자해", "사라지고 싶", "죽을래", "살기 싫"],
             lines: ["많이 힘들구나. 혼자 견디지 말고 지금 109에 전화해 줘. 나도 여기 있을게."],
             mood: .normal),
        Rule(words: ["지겨", "지루", "심심", "따분"],
             lines: ["왜 지겨워… 힘내! 나랑 바깥 구경하러 갈래?", "심심하구나. 우리 오늘 제일 예쁜 거 하나 찍어 볼까?"],
             mood: .surprised),
        Rule(words: ["피곤", "졸려", "졸리", "지쳐", "힘들"],
             lines: ["오늘 많이 애썼구나. 잠깐 쉬어도 괜찮아.", "토닥토닥, 따뜻한 거 마시고 쉬자."],
             mood: .normal),
        Rule(words: ["배고", "맛있", "먹고", "밥", "간식"],
             lines: ["냠냠! 맛있는 거 먹으면 나한테도 보여 줘!", "나도 배고파… 맛있는 거 찍으러 가자!"],
             mood: .yum),
        Rule(words: ["슬퍼", "우울", "속상", "울고", "외로"],
             lines: ["속상했구나. 내가 옆에 둥실 있을게.", "괜찮아, 오늘은 내가 꼭 붙어 있을게."],
             mood: .normal),
        Rule(words: ["좋아", "신나", "행복", "기뻐", "최고"],
             lines: ["와, 나도 덩달아 신나! 이 기분 사진으로 남기자!", "좋은 일 있었구나! 나도 방긋!"],
             mood: .smile),
        Rule(words: ["사랑", "고마", "보고 싶"],
             lines: ["나도 너 정말 좋아! 헤헤.", "고마워, 너랑 있으면 둥실둥실 기분 좋아."],
             mood: .awe),
        Rule(words: ["안녕", "하이", "반가"],
             lines: ["안녕! 오늘은 뭐 찍을까?", "반가워! 기다리고 있었어."],
             mood: .smile),
        Rule(words: ["사진", "찍"],
             lines: ["좋아! 나를 톡 누르면 찰칵 찍혀.", "찍자 찍자! 예쁜 빛을 찾아보자."],
             mood: .smile),
    ]

    private static let fallback = ["그렇구나! 더 얘기해 줘.", "음음, 듣고 있어!", "우와, 그래서 어떻게 됐어?"]

    static func reply(to text: String, roll: Double) -> TalkReply {
        let pick = { (lines: [String]) in lines[min(lines.count - 1, max(0, Int(roll * Double(lines.count))))] }
        let spoken = text.replacingOccurrences(of: " ", with: "")
        for rule in rules where rule.words.contains(where: { spoken.contains($0.replacingOccurrences(of: " ", with: "")) }) {
            return TalkReply(pick(rule.lines), rule.mood)
        }
        return TalkReply(pick(fallback), .smile)
    }
}
