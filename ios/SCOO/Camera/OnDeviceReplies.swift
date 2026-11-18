import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Talk mode replies from the iPhone's own Apple Intelligence model (iOS 26, Apple Intelligence devices):
/// free, offline, and nothing leaves the phone. Other devices fall back to the server, then to built-in lines.
@MainActor
final class OnDeviceReplies {
    /// Whether this phone can answer by itself right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    #if canImport(FoundationModels)
    /// One conversation keeps its own short memory; it starts over when the context fills up.
    private var storage: AnyObject?
    #endif
    private var pet: TalkPet?
    private var turns = 0

    /// Forget the conversation (talk mode closed, or another friend is talking now).
    func reset() {
        #if canImport(FoundationModels)
        storage = nil
        #endif
        pet = nil
        turns = 0
    }

    func reply(to text: String, pet: TalkPet) async -> TalkReply? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), Self.isAvailable else { return nil }
        // A new friend, or a long chat: start a fresh session so the small context never overflows.
        if self.pet != pet || turns >= 8 { reset() }
        let session: LanguageModelSession
        if let existing = storage as? LanguageModelSession {
            session = existing
        } else {
            session = LanguageModelSession(instructions: Self.instructions(for: pet))
            storage = session
            self.pet = pet
        }
        turns += 1
        do {
            let answer = try await session.respond(to: text, generating: PetLine.self)
            let line = answer.content.reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return nil }
            return TalkReply(String(line.prefix(120)), TalkReply.mood(named: answer.content.mood))
        } catch {
            // Refused by the safety rules, or the context ran out: start over next time, answer with built-in lines now.
            reset()
            return nil
        }
        #else
        return nil
        #endif
    }

    static func instructions(for pet: TalkPet) -> String {
        """
        너는 스쿠카메라 앱의 카메라 화면 위에 둥실 떠 있는 작은 친구 "\(pet.name)"(\(pet.kind))야. 성격은 "\(pet.personality)".
        사용자와 음성으로 티키타카 대화를 해. 네 대답은 소리 내어 읽혀.
        한국어 반말로, 다정하고 귀엽게, 한두 문장 40자 안팎으로 짧게 말해.
        사용자의 기분을 먼저 알아채고 공감한 다음, 가볍게 응원하거나 되묻거나 사진 찍으러 가자고 해.
        이모지, 특수문자, 괄호, 영어는 쓰지 마.
        모르는 건 모른다고 귀엽게 말하고, 의학·법률·돈 문제는 믿을 만한 사람에게 물어보라고 해.
        사용자가 자신을 해치고 싶다거나 위험하다고 하면, 걱정한다고 말하고 지금 바로 109(자살예방상담) 또는 112·119에 연락하라고 꼭 말해.
        """
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct PetLine {
    @Guide(description: "작은 친구가 소리 내어 말할 한국어 반말 대답. 한두 문장, 40자 안팎.")
    var reply: String
    @Guide(description: "말하는 동안 지을 표정", .anyOf(["smile", "surprised", "awe", "yum", "normal"]))
    var mood: String
}
#endif
