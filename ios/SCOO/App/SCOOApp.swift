import SwiftUI

@main
@MainActor
struct SCOOApp: App {
    @StateObject private var garden = GardenStore()
    var body: some Scene {
        WindowGroup {
            CameraScreen()
                .environmentObject(garden)
                .preferredColorScheme(.light)
                .task { await garden.load() }
        }
    }
}

enum Palette {
    static let cream = Color(red: 0.95, green: 0.95, blue: 0.91)
    static let ink = Color(red: 0.16, green: 0.24, blue: 0.18)
    static let moss = Color(red: 0.27, green: 0.40, blue: 0.28)
    static let sage = Color(red: 0.52, green: 0.62, blue: 0.43)
    static let silver = LinearGradient(colors: [Color(white: 0.93), Color(white: 0.84), Color(white: 0.91)], startPoint: .topLeading, endPoint: .bottomTrailing)
}
