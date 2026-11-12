import SwiftUI
import UIKit
import PhotosUI
import ImageIO

struct AlbumScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: PhotoRecord?
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    var body: some View {
        NavigationStack {
            ScrollView {
                if garden.snapshot.photos.isEmpty {
                    ContentUnavailableView("아직 작은 순간을 기다려요", systemImage: "camera", description: Text("사진을 찍으면 이곳에 차곡차곡 쌓여요.")).padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(garden.snapshot.photos) { photo in
                            Button { selected = photo } label: {
                                VStack(spacing: 10) {
                                    PhotoThumbnail(url: garden.fileURL(for: photo)).aspectRatio(3 / 4, contentMode: .fit).clipped()
                                    HStack { Text(photo.date, format: .dateTime.year(.twoDigits).month(.twoDigits).day(.twoDigits)); Spacer(); Text("+\(photo.experience)").foregroundStyle(Palette.moss) }.font(.system(size: 9, design: .monospaced))
                                }.padding(9).background(.white.opacity(0.7)).foregroundStyle(Palette.ink)
                            }.buttonStyle(.plain).accessibilityLabel("\(photo.filter) 사진, \(photo.experience) EXP")
                        }
                    }.padding(20)
                }
            }.background(Palette.cream)
                .navigationTitle("초록을 키운 사진들").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
                .sheet(item: $selected) { photo in PhotoDetail(photo: photo).environmentObject(garden) }
        }.tint(Palette.moss)
    }
}

struct PhotoThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Rectangle().fill(Palette.sage.opacity(0.15)).overlay { Image(systemName: "photo").foregroundStyle(Palette.sage) } }
        }.task(id: url) {
            let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 640,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ] as CFDictionary) else { return nil }
                return UIImage(cgImage: thumbnail)
            }.value
            if !Task.isCancelled { image = loaded }
        }
    }
}

private struct PhotoDetail: View {
    let photo: PhotoRecord
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var confirmingDelete = false
    @State private var saving = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let image { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8)) }
                    HStack { Text(photo.filter).font(.title2.weight(.medium)); Spacer(); Text("+\(photo.experience) EXP").font(.caption.monospaced()).foregroundStyle(Palette.sage) }
                    Text(photo.date, format: .dateTime.year().month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                    Text(photo.classificationNote).font(.caption).foregroundStyle(.secondary)
                    Text("빛·선명도 보너스 +\(photo.bonus)").font(.caption).foregroundStyle(Palette.moss)
                    Button {
                        saving = true
                        Task {
                            defer { saving = false }
                            do { let data = try Data(contentsOf: garden.fileURL(for: photo)); try await PhotoLibraryWriter.save(data); message = "사진 앱에 저장했어요." }
                            catch { message = error.localizedDescription }
                        }
                    } label: { Label(saving ? "저장 중…" : "사진 앱에 저장", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity).padding(14) }.buttonStyle(.borderedProminent).disabled(saving)
                    Button("앱 앨범에서 삭제", role: .destructive) { confirmingDelete = true }.font(.caption).padding(.top, 10)
                }.padding(22)
            }.background(Palette.cream).navigationTitle("작은 순간").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
                .task { let url = garden.fileURL(for: photo); image = await Task.detached { UIImage(contentsOfFile: url.path) }.value }
                .confirmationDialog("앱에서 이 사진을 삭제할까요? 마리모의 성장은 남아요. 사진 앱에 저장한 복사본은 유지돼요.", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("사진 삭제", role: .destructive) { Task { await garden.delete(photo); if garden.snapshot.photos.contains(where: { $0.id == photo.id }) == false { dismiss() } } }
                }
                .alert("SCOO", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("확인") { message = nil } } message: { Text(message ?? "") }
        }.tint(Palette.moss)
    }
}
