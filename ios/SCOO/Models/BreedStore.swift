import Foundation
import Combine

/// Babies are kept in their own file next to the garden, so the garden index format stays untouched.
@MainActor
final class BreedStore: ObservableObject {
    /// The one store every screen shares, so a baby named or grown on one screen shows the same everywhere.
    /// (Tests make their own with `init(directory:)`.)
    static let shared: BreedStore = {
        let store = BreedStore()
        store.load()
        return store
    }()

    @Published private(set) var breeds: [Breed] = []
    @Published var message: String?
    private let url: URL

    init(directory: URL = PhotoRepository.directory) {
        url = directory.appendingPathComponent("breeds.json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: url.path) else { breeds = []; return }
        do { breeds = try JSONDecoder().decode([Breed].self, from: Data(contentsOf: url)) }
        catch { message = "아기 기록을 읽지 못했어요. 기존 파일은 그대로 두었어요." }
    }

    @discardableResult
    func hatch(a: String, b: String, moments: Int, now: Date = Date()) throws -> Breed {
        let baby = Breed(id: UUID(), parentA: a, parentB: b, born: now, bornAtMoment: moments)
        try write([baby] + breeds)
        return baby
    }

    /// A baby of two parents that may themselves be bred babies (재교배).
    @discardableResult
    func hatch(_ a: BreedParent, _ b: BreedParent, moments: Int, now: Date = Date()) throws -> Breed {
        var baby = Breed(id: UUID(), parentA: a.id, parentB: b.id, born: now, bornAtMoment: moments)
        if a.isBreed || b.isBreed {
            baby.shapeA = a.shape
            baby.colorB = b.color
            baby.nameA = a.isBreed ? a.name : nil
            baby.nameB = b.isBreed ? b.name : nil
            baby.artA = a.art
            baby.artB = b.art
            baby.generation = max(a.generation, b.generation) + 1
        }
        try write([baby] + breeds)
        return baby
    }

    /// A baby leaves in a glass bottle.
    func remove(_ id: UUID) throws {
        try write(breeds.filter { $0.id != id })
    }

    /// A baby arrives from a glass bottle.
    func adopt(_ baby: Breed) throws {
        guard !breeds.contains(where: { $0.id == baby.id }) else { return }
        try write([baby] + breeds)
    }

    /// Names a baby (nil or "" = back to the made-up name). Checked by `NameFilter`.
    func rename(_ id: UUID, to raw: String?) throws {
        load()
        guard let index = breeds.firstIndex(where: { $0.id == id }) else { return }
        var next = breeds
        if let raw, !NameFilter.clean(raw).isEmpty {
            next[index].nickname = try NameFilter.accept(raw).get()
        } else {
            next[index].nickname = nil
        }
        try write(next)
    }

    /// A photo taken while this baby floated: its EXP goes to this baby alone.
    @discardableResult
    func gain(_ exp: Int, id: UUID, moments: Int) -> Breed? {
        load()
        guard let index = breeds.firstIndex(where: { $0.id == id }) else { return nil }
        var next = breeds
        next[index].experience = next[index].xp(moments: moments) + max(0, exp)
        next[index].together = (next[index].together ?? 0) + 1
        do { try write(next) } catch { message = "아기 기록을 저장하지 못했어요."; return nil }
        return next[index]
    }

    /// Babies from before they grew by floating keep what they grew so far, and from now on grow only when they
    /// float. Run once the garden's photo count is known; does nothing when there is nothing to change.
    func freezeLegacy(moments: Int) {
        load()
        guard breeds.contains(where: { $0.experience == nil }) else { return }
        let next = breeds.map { baby -> Breed in
            var baby = baby
            if baby.experience == nil { baby.experience = baby.xp(moments: moments) }
            return baby
        }
        try? write(next)
    }

    private func write(_ next: [Breed]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: url, options: .atomic)
        breeds = next
        WidgetBridge.refresh()
    }
}
