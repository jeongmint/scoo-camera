import SwiftUI
import UIKit
import ImageIO

/// 오늘의 작은 필름: today's photos stacked like a photo-booth strip, with the friend, the date and a short line.
struct FilmStrip: View {
    let photos: [UIImage]
    let date: Date
    let caption: String
    let friendAsset: String?

    var body: some View {
        VStack(spacing: 14) {
            Text(date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.ink.opacity(0.7))
            ForEach(Array(photos.enumerated()), id: \.offset) { _, image in
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 520, height: 390)
                    .clipped()
            }
            HStack(spacing: 14) {
                Group {
                    if let friendAsset {
                        Image(friendAsset).resizable().scaledToFit()
                    } else {
                        MarimoView(size: 96, floats: false)
                    }
                }
                .frame(width: 96, height: 96)
                Text(caption).font(.system(size: 26, weight: .semibold)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            Text("SCOO · Eternal").font(.system(size: 14, design: .serif)).italic().foregroundStyle(Palette.sage)
        }
        .padding(28)
        .frame(width: 576)
        .background(Palette.cream)
    }

    /// A short line for the day, from what was photographed.
    static func caption(friend: String, photos: [PhotoRecord]) -> String {
        guard !photos.isEmpty else { return "\(friend)와 함께한 하루" }
        let food = photos.filter(\.isFood).count
        if food * 2 >= photos.count { return "\(friend)와 맛있는 것만 잔뜩 본 날" }
        if photos.count >= 4 { return "\(friend)와 부지런히 담은 하루" }
        return "\(friend)와 함께 본 오늘"
    }

    /// Downscaled copies of today's photos (newest four), oldest first like a strip.
    static func images(for records: [PhotoRecord], url: (PhotoRecord) -> URL) -> [UIImage] {
        records.prefix(4).reversed().compactMap { record in
            guard let source = CGImageSourceCreateWithURL(url(record) as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceThumbnailMaxPixelSize: 1040,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: image)
        }
    }
}

/// Shows the rendered strip with save and share.
struct FilmStripSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: 260)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
                    HStack(spacing: 12) {
                        Button {
                            saving = true
                            Task {
                                defer { saving = false }
                                guard let data = image.jpegData(compressionQuality: 0.92) else { return }
                                do { try await PhotoLibraryWriter.save(data); message = "사진 앱에 저장했어요." }
                                catch { message = error.localizedDescription }
                            }
                        } label: { Label(saving ? "저장 중…" : "사진 앱에 저장", systemImage: "square.and.arrow.down") }
                            .buttonStyle(.borderedProminent).disabled(saving)
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("오늘의 작은 필름", image: Image(uiImage: image))) {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(24)
            }
            .background(Palette.cream)
            .navigationTitle("오늘의 작은 필름")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .alert("SCOO", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("확인") { message = nil }
            } message: { Text(message ?? "") }
        }
        .tint(Palette.moss)
    }
}
