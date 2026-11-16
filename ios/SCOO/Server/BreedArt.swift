import UIKit

/// Pictures of bred babies drawn by the server (`breed-image` edge function, GPT Image).
/// A pair is drawn once for everyone; this device keeps its own copy in breed-art/<a>-<b>.png.
@MainActor
enum BreedArt {
    static var folder: URL { PhotoRepository.directory.appendingPathComponent("breed-art", isDirectory: true) }

    static func fileURL(_ key: String) -> URL { folder.appendingPathComponent("\(key).png") }

    /// The downloaded picture for a pair, if this device has it.
    static func image(_ key: String) -> UIImage? { UIImage(contentsOfFile: fileURL(key).path) }

    /// Whether the baby already has real art: drawn into the app, or downloaded earlier.
    static func hasArt(_ breed: Breed) -> Bool {
        UIImage(named: breed.babyAsset) != nil || FileManager.default.fileExists(atPath: fileURL(breed.key).path)
    }

    static var canDraw: Bool { SupabaseConfig.isConfigured }

    /// Asks the server for the pair's picture (drawing it if nobody has yet) and saves it on this device.
    static func fetch(_ breed: Breed, client: SupabaseClient = .shared) async throws {
        guard !hasArt(breed) else { return }
        guard let mother = breed.mother, let father = breed.father,
              let imageA = parentPNG(mother.assetName), let imageB = parentPNG(father.assetName) else {
            throw SCOOError.message("부모 그림을 찾지 못했어요.")
        }
        let data = try await client.invoke("breed-image", [
            "parentA": breed.parentA, "parentB": breed.parentB,
            "imageA": imageA.base64EncodedString(), "imageB": imageB.base64EncodedString(),
        ])
        struct Answer: Decodable { let url: URL }
        let answer = try JSONDecoder().decode(Answer.self, from: data)
        let (png, response) = try await URLSession.shared.data(from: answer.url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, UIImage(data: png) != nil else {
            throw SCOOError.message("그림을 받지 못했어요.")
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: fileURL(breed.key), options: .atomic)
    }

    /// A parent's picture, shrunk to at most 512 px so the request stays small.
    private static func parentPNG(_ assetName: String) -> Data? {
        guard let image = UIImage(named: assetName) else { return nil }
        let side = min(512, max(image.size.width * image.scale, image.size.height * image.scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.pngData()
    }
}
