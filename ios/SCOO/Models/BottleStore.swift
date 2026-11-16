import Foundation
import Combine

/// Bottles sent and received, kept in bottles.json next to the garden.
/// Babies move between this and `BreedStore`: sending removes one, opening a bottle adopts one.
@MainActor
final class BottleStore: ObservableObject {
    @Published private(set) var bottles: [Bottle] = []
    @Published var message: String?
    private let url: URL
    private let ocean: BottleOcean

    init(directory: URL = PhotoRepository.directory, ocean: BottleOcean = LocalOcean()) {
        url = directory.appendingPathComponent("bottles.json")
        self.ocean = ocean
    }

    func load() {
        guard FileManager.default.fileExists(atPath: url.path) else { bottles = []; return }
        do { bottles = try JSONDecoder().decode([Bottle].self, from: Data(contentsOf: url)) }
        catch { message = "유리병 기록을 읽지 못했어요. 기존 파일은 그대로 두었어요." }
    }

    func canSend(now: Date = Date(), fast: Bool) -> Bool { BottleRules.canSend(bottles, now: now, fast: fast) }

    /// Puts a baby in a bottle. The sea answers with another bottle on its way here.
    @discardableResult
    func send(_ baby: Breed, wantsNews: Bool, from district: String?, breeds: BreedStore, fast: Bool, now: Date = Date()) throws -> Bottle {
        guard canSend(now: now, fast: fast) else { throw SCOOError.message("유리병은 하루에 \(BottleRules.dailySends)번 띄울 수 있어요.") }
        let origin = baby.origin ?? district ?? "서울 어딘가"
        let outgoing = Bottle(id: UUID(), direction: .outgoing, parentA: baby.parentA, parentB: baby.parentB, origin: origin,
                              sentAt: now, arrivesAt: now.addingTimeInterval(BottleRules.travelTime(fast: fast)), wantsNews: wantsNews)
        let incoming = ocean.bottleInReturn(for: outgoing, fast: fast)
        try write([incoming, outgoing] + bottles)
        try breeds.remove(baby.id)
        return outgoing
    }

    /// Opens an arrived bottle and takes the baby in.
    @discardableResult
    func open(_ bottle: Bottle, breeds: BreedStore, moments: Int, now: Date = Date()) throws -> Breed {
        // Check the stored bottle, not the caller's copy, so a bottle can only be opened once.
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }),
              bottles[index].direction == .incoming, bottles[index].hasArrived(at: now), !bottles[index].opened else {
            throw SCOOError.message("아직 열 수 없는 유리병이에요.")
        }
        let bottle = bottles[index]
        let baby = Breed(id: bottle.id, parentA: bottle.parentA, parentB: bottle.parentB, born: now, bornAtMoment: moments,
                         origin: bottle.origin, adopted: true)
        try breeds.adopt(baby)
        var next = bottles
        next[index].opened = true
        try write(next)
        return baby
    }

    private func write(_ next: [Bottle]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: url, options: .atomic)
        bottles = next
    }
}
