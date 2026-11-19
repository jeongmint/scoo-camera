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

    /// The default floating Mori, or the character picked in the camera menu.
    static func of(_ species: Species?, moriName: String, personality: String) -> TalkPet {
        guard let species, species.id != "mori" else {
            return TalkPet(name: species == nil ? moriName : "모리", kind: "동글동글 이끼 공 마리모", personality: personality,
                           tint: (0.47, 0.66, 0.30), pitch: 1.25)
        }
        let look = looks[species.id] ?? Look(kind: "작은 친구", tint: (0.62, 0.74, 0.58), pitch: 1.3)
        return TalkPet(name: species.name, kind: look.kind, personality: personality, tint: look.tint, pitch: look.pitch)
    }

    private struct Look {
        let kind: String
        let tint: (red: Double, green: Double, blue: Double)
        let pitch: Float
    }

    /// What each character is and its color for the glowing frame, read off its picture.
    private static let looks: [String: Look] = [
        "gwiyo": Look(kind: "작은 금색 방울", tint: (0.86, 0.68, 0.32), pitch: 1.45),
        "kuru": Look(kind: "몽실몽실 흰 구름", tint: (0.58, 0.78, 0.96), pitch: 1.3),
        "nyamo": Look(kind: "통통한 치즈 고양이", tint: (0.96, 0.72, 0.52), pitch: 1.4),
        "happy": Look(kind: "초록 목도리를 한 눈사람", tint: (0.62, 0.78, 0.56), pitch: 1.2),
        "baseball": Look(kind: "빨간 실밥 야구공 도도", tint: (0.86, 0.32, 0.30), pitch: 1.35),
        "chiko": Look(kind: "볼이 통통한 다람쥐", tint: (0.93, 0.66, 0.38), pitch: 1.5),
        "deogi": Look(kind: "귀가 축 처진 강아지", tint: (0.82, 0.62, 0.40), pitch: 1.25),
        "dia": Look(kind: "새빨간 사과", tint: (0.88, 0.22, 0.24), pitch: 1.4),
        "dochi": Look(kind: "포슬포슬 고슴도치", tint: (0.64, 0.47, 0.32), pitch: 1.35),
        "hechi": Look(kind: "물가에 사는 납작 꼬리 친구", tint: (0.52, 0.38, 0.28), pitch: 1.1),
        "huu": Look(kind: "깃털 보송한 부엉이", tint: (0.72, 0.60, 0.52), pitch: 1.05),
        "luna": Look(kind: "동그란 보름달", tint: (0.93, 0.88, 0.68), pitch: 1.15),
        "mellu": Look(kind: "그물무늬 멜론", tint: (0.72, 0.82, 0.42), pitch: 1.3),
        "mupu": Look(kind: "꼬리가 두툼한 너구리", tint: (0.56, 0.46, 0.38), pitch: 1.15),
        "otter": Look(kind: "튜브를 낀 수달", tint: (0.45, 0.80, 0.72), pitch: 1.35),
        "popo": Look(kind: "뽀얀 찻주전자", tint: (0.70, 0.82, 0.60), pitch: 1.2),
        "riru": Look(kind: "하얀 속살 리치", tint: (0.95, 0.45, 0.50), pitch: 1.45),
        "sia": Look(kind: "보랏빛 블루베리", tint: (0.42, 0.50, 0.82), pitch: 1.4),
        "sunny": Look(kind: "반짝이는 해님", tint: (0.98, 0.80, 0.25), pitch: 1.45),
        "suri": Look(kind: "줄무늬 수박", tint: (0.36, 0.66, 0.32), pitch: 1.3),
        "tangerine": Look(kind: "새콤한 귤", tint: (0.98, 0.56, 0.16), pitch: 1.5),
        "tori": Look(kind: "분홍 귀 하얀 토끼", tint: (0.95, 0.74, 0.80), pitch: 1.5),
        "toto": Look(kind: "고리를 두른 행성", tint: (0.76, 0.63, 0.90), pitch: 1.2),
        "yarn": Look(kind: "분홍 실타래", tint: (0.92, 0.56, 0.62), pitch: 1.35),
        "komi": Look(kind: "길을 알려 주는 금빛 나침반", tint: (0.86, 0.66, 0.36), pitch: 1.3),
        "mello": Look(kind: "노래하는 보랏빛 오르골", tint: (0.78, 0.62, 0.84), pitch: 1.45),
        "bandi": Look(kind: "반딧불이가 사는 작은 등불", tint: (0.86, 0.84, 0.46), pitch: 1.35),
        "lumi": Look(kind: "반짝반짝 미러볼", tint: (0.84, 0.74, 0.92), pitch: 1.4),
        "bosong": Look(kind: "분홍 리본을 맨 보송보송 친구", tint: (0.95, 0.78, 0.80), pitch: 1.45),
        "chiru": Look(kind: "꼬리가 복슬한 친칠라", tint: (0.64, 0.64, 0.72), pitch: 1.5),
        "cro": Look(kind: "돌돌 말린 시나몬롤", tint: (0.90, 0.60, 0.30), pitch: 1.4),
        "inky": Look(kind: "깃펜을 꽂은 잉크병", tint: (0.30, 0.32, 0.56), pitch: 1.15),
        "momo": Look(kind: "말랑한 복숭아", tint: (0.98, 0.66, 0.56), pitch: 1.45),
        "mumu": Look(kind: "잎이 싱싱한 순무", tint: (0.90, 0.62, 0.74), pitch: 1.3),
        "pico": Look(kind: "속이 달콤한 무화과", tint: (0.58, 0.28, 0.44), pitch: 1.3),
        "posil": Look(kind: "포실포실 아기 물범", tint: (0.90, 0.84, 0.76), pitch: 1.4),
        "rora": Look(kind: "무지갯빛 유리구슬", tint: (0.80, 0.74, 0.92), pitch: 1.4),
        "bomi": Look(kind: "벚꽃을 꽂은 봄 개구리", tint: (0.62, 0.74, 0.46), pitch: 1.4),
        "soru": Look(kind: "하늘색 여름 아이스크림", tint: (0.62, 0.82, 0.96), pitch: 1.5),
        "doto": Look(kind: "도토리를 안은 가을 다람쥐", tint: (0.88, 0.52, 0.26), pitch: 1.45),
    ]
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
