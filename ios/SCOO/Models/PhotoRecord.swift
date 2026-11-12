import Foundation

struct PhotoRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let filename: String
    let filter: String
    let isFood: Bool
    let mode: CaptureMode
    let experience: Int
    let bonus: Int
    let classificationNote: String
}

struct GardenSnapshot: Codable {
    var name = "모리"
    var experience = 0
    var moments = 0
    var birthday = Date()
    var photos: [PhotoRecord] = []
}

struct ProcessedPhoto {
    let jpeg: Data
    let isFood: Bool
    let bonus: Int
    let classificationNote: String
}

enum SCOOError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
