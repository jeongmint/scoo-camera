import Foundation
import Combine

/// Babies are kept in their own file next to the garden, so the garden index format stays untouched.
@MainActor
final class BreedStore: ObservableObject {
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
        let next = [baby] + breeds
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: url, options: .atomic)
        breeds = next
        return baby
    }
}
