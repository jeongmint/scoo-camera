import Foundation
import Combine

actor PhotoRepository {
    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SCOO", isDirectory: true)
    private var snapshot: GardenSnapshot?

    func load() throws -> GardenSnapshot {
        if let snapshot { return snapshot }
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let url = Self.directory.appendingPathComponent("garden.json")
        let value: GardenSnapshot
        if FileManager.default.fileExists(atPath: url.path) {
            // Preserve an unreadable index rather than replacing it with an empty garden.
            value = try JSONDecoder().decode(GardenSnapshot.self, from: Data(contentsOf: url))
        } else {
            value = GardenSnapshot()
        }
        snapshot = value
        return value
    }

    private func persist(_ next: GardenSnapshot) throws {
        let data = try JSONEncoder().encode(next)
        try data.write(to: Self.directory.appendingPathComponent("garden.json"), options: .atomic)
        snapshot = next
    }

    func add(_ processed: ProcessedPhoto, filter: FilmLook, mode: CaptureMode) throws -> GardenSnapshot {
        var next = try load()
        let id = UUID()
        let filename = "\(id.uuidString).jpg"
        let gain = GrowthRules.reward(isFood: processed.isFood, bonus: processed.bonus)
        let photo = PhotoRecord(id: id, date: Date(), filename: filename, filter: filter.rawValue,
                                isFood: processed.isFood, mode: mode, experience: gain,
                                bonus: processed.bonus, classificationNote: processed.classificationNote)
        let url = Self.directory.appendingPathComponent(filename)
        try processed.jpeg.write(to: url, options: .atomic)
        next.photos.insert(photo, at: 0)
        next.experience += gain
        next.moments += 1
        do { try persist(next) }
        catch { try? FileManager.default.removeItem(at: url); throw error }
        return next
    }

    func rename(_ name: String) throws -> GardenSnapshot {
        var next = try load()
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12))
        guard !clean.isEmpty else { throw SCOOError.message("이름을 한 글자 이상 적어 주세요.") }
        next.name = clean
        try persist(next)
        return next
    }

    func delete(_ photo: PhotoRecord) throws -> GardenSnapshot {
        var next = try load()
        next.photos.removeAll { $0.id == photo.id }
        // The metadata commits before file removal. Orphan cleanup is safe on a later load.
        try persist(next)
        try? FileManager.default.removeItem(at: Self.directory.appendingPathComponent(photo.filename))
        return next
    }
}

@MainActor
final class GardenStore: ObservableObject {
    @Published private(set) var snapshot = GardenSnapshot()
    @Published private(set) var ready = false
    @Published var message: String?
    private let repository = PhotoRepository()

    var growth: Growth { GrowthRules.growth(for: snapshot.experience) }
    var day: Int { max(1, Calendar.current.dateComponents([.day], from: snapshot.birthday, to: Date()).day.map { $0 + 1 } ?? 1) }

    func load() async {
        do { snapshot = try await repository.load(); ready = true }
        catch { message = "기록을 읽지 못했어요. 기존 데이터는 보존했어요. \(error.localizedDescription)" }
    }

    @discardableResult
    func add(_ photo: ProcessedPhoto, filter: FilmLook, mode: CaptureMode) async throws -> Int {
        let previous = snapshot.experience
        snapshot = try await repository.add(photo, filter: filter, mode: mode)
        return snapshot.experience - previous
    }

    func rename(_ name: String) async {
        do { snapshot = try await repository.rename(name) }
        catch { message = error.localizedDescription }
    }

    func delete(_ photo: PhotoRecord) async {
        do { snapshot = try await repository.delete(photo) }
        catch { message = error.localizedDescription }
    }

    func fileURL(for photo: PhotoRecord) -> URL {
        PhotoRepository.directory.appendingPathComponent(photo.filename)
    }
}
