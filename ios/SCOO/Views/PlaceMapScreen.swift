import SwiftUI
import MapKit

/// The map guestbook: every photo that remembers where it was taken becomes a small round pin.
/// Not live locations — only places the user has been and photographed.
struct PlaceMapScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic
    @State private var selected: PhotoRecord?

    private struct Pin: Identifiable {
        let photo: PhotoRecord
        let coordinate: CLLocationCoordinate2D
        var id: UUID { photo.id }
    }

    private var pinned: [Pin] {
        garden.snapshot.photos.compactMap { photo in
            photo.location.map { Pin(photo: photo, coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
        }
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                ForEach(pinned) { pin in
                    Annotation(pin.photo.date.formatted(date: .abbreviated, time: .omitted), coordinate: pin.coordinate) {
                        Button { selected = pin.photo } label: {
                            PhotoThumbnail(url: garden.fileURL(for: pin.photo))
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .overlay { Circle().stroke(.white, lineWidth: 2.5) }
                                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(pin.photo.date.formatted(date: .long, time: .shortened))에 찍은 사진")
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .overlay(alignment: .bottom) {
                Text(pinned.isEmpty ? "사진을 찍으면 그 자리에 작은 핀이 남아요." : "다녀간 곳 \(pinned.count)군데")
                    .font(.footnote)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
            .navigationTitle("지도 방명록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .sheet(item: $selected) { photo in PhotoDetail(photo: photo).environmentObject(garden) }
        }
        .tint(Palette.moss)
    }
}
