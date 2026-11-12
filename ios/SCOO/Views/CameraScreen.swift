import SwiftUI
import UIKit
import PhotosUI

struct CameraScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraService()
    @AppStorage("dateStamp") private var dateStamp = true
    @AppStorage("autoSave") private var autoSave = false
    @State private var look: FilmLook = .warm
    @State private var mode: CaptureMode = .auto
    @State private var flash = false
    @State private var processing = false
    @State private var shutterFlash = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var sheet: CameraSheet?
    @State private var selectedItem: PhotosPickerItem?
    @State private var focusPoint: CGPoint?
    @State private var previewAspect: CGFloat = 3 / 4
    @State private var pipeline = PhotoPipeline()

    private enum CameraSheet: String, Identifiable { case album, garden, settings; var id: String { rawValue } }

    var body: some View {
        GeometryReader { geometry in
            let previewHeight = max(130, min(geometry.size.width * 1.25, geometry.size.height - 425))
            VStack(spacing: 13) {
                header
                viewfinder(height: previewHeight)
                filters
                captureControls
                marimoAccessory
            }.padding(.horizontal, 17).padding(.vertical, 10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Palette.silver.ignoresSafeArea())
                .overlay(alignment: .top) {
                    if let toast { Text(toast).font(.caption).multilineTextAlignment(.center).padding(14).background(Palette.ink.opacity(0.95), in: Capsule()).foregroundStyle(Palette.cream).padding(.horizontal, 20).padding(.top, 65).transition(.move(edge: .top).combined(with: .opacity)) }
                }
        }
        .tint(Palette.moss)
        .task { camera.setLook(look); camera.start() }
        .onChange(of: look) { _, newValue in camera.setLook(newValue) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && sheet == nil { camera.start() } else { camera.stop() }
        }
        .onChange(of: sheet) { _, value in if value != nil { camera.stop() } }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    processing = true
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw SCOOError.message("사진을 불러오지 못했어요.") }
                    await process(data, look: look, mode: mode, stamp: dateStamp)
                } catch { processing = false; notify(error.localizedDescription) }
                selectedItem = nil
            }
        }
        .onChange(of: camera.errorMessage) { _, error in if let error { notify(error) } }
        .onChange(of: garden.message) { _, error in if let error { notify(error); garden.message = nil } }
        .sheet(item: $sheet, onDismiss: { if scenePhase == .active { camera.start() } }) { value in
            switch value {
            case .album: AlbumScreen().environmentObject(garden)
            case .garden: GardenScreen().environmentObject(garden)
            case .settings: SettingsScreen()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("scoo.").font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-2)
            Text("DIGITAL\nPOCKET CAMERA").font(.system(size: 6, weight: .medium, design: .monospaced)).tracking(1.6).foregroundStyle(.secondary)
            Spacer()
            Circle().fill(camera.isRunning ? Palette.sage : .gray.opacity(0.3)).frame(width: 5, height: 5)
            Button { sheet = .settings } label: { Image(systemName: "gearshape").font(.system(size: 18)).frame(width: 44, height: 44) }.accessibilityLabel("설정")
        }.foregroundStyle(Palette.ink)
    }

    private func viewfinder(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            GeometryReader { bounds in
                ZStack {
                    Color(red: 0.13, green: 0.18, blue: 0.14)
                    if let frame = camera.frame {
                        Image(uiImage: frame).resizable().scaledToFill().frame(width: bounds.size.width, height: bounds.size.height).clipped()
                    }
                    if !camera.isRunning {
                        VStack(spacing: 15) {
                            Image(systemName: camera.permissionDenied ? "camera.fill" : "camera.aperture").font(.system(size: 34, weight: .ultraLight))
                            Text(camera.permissionDenied ? "카메라를 허용하면\n오늘의 순간이 보여요." : "당신의 작은 순간을 기다려요.").font(.caption).multilineTextAlignment(.center)
                            Button(camera.permissionDenied ? "설정에서 카메라 허용" : "카메라 켜기") {
                                if camera.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                                else { camera.start() }
                            }.font(.caption).padding(.horizontal, 15).padding(.vertical, 9).background(.white.opacity(0.15), in: Capsule())
                            Text("카메라가 없으면 아래 앨범 버튼으로 체험해요.").font(.system(size: 9)).opacity(0.6)
                        }.foregroundStyle(.white)
                    }
                    VStack {
                        HStack {
                            Text(mode == .auto ? "AUTO" : mode == .food ? "FOOD" : "DAILY").font(.system(size: 10, weight: .medium, design: .monospaced)).padding(4).overlay(Rectangle().stroke(.white.opacity(0.7)))
                            Spacer()
                            Button { flash.toggle() } label: { Image(systemName: flash ? "bolt.fill" : "bolt.slash").font(.system(size: 14)).frame(width: 40, height: 40) }.disabled(!camera.hasFlash).opacity(camera.hasFlash ? 1 : 0.4).accessibilityLabel(flash ? "플래시 끄기" : "플래시 켜기")
                        }
                        Spacer()
                        HStack {
                            Text(look.rawValue.uppercased()).font(.system(size: 9, design: .monospaced))
                            Spacer()
                            if dateStamp { Text(Date(), format: .dateTime.year(.twoDigits).month(.twoDigits).day(.twoDigits)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.orange.opacity(0.85)) }
                        }
                    }.padding(13).foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                    if let focusPoint {
                        RoundedRectangle(cornerRadius: 2).stroke(Color.yellow.opacity(0.9), lineWidth: 1).frame(width: 52, height: 52).position(focusPoint).allowsHitTesting(false)
                    }
                    if shutterFlash { Color.white.opacity(0.85).allowsHitTesting(false) }
                }.contentShape(Rectangle())
                    .onTapGesture { point in
                        guard camera.isRunning else { return }
                        focusPoint = point
                        // Portrait, centered aspect-fill preview -> sensor coordinates.
                        let source = camera.frame?.size ?? CGSize(width: 3, height: 4)
                        let scale = max(bounds.size.width / source.width, bounds.size.height / source.height)
                        let normalizedX = (point.x + (source.width * scale - bounds.size.width) / 2) / (source.width * scale)
                        let normalizedY = (point.y + (source.height * scale - bounds.size.height) / 2) / (source.height * scale)
                        camera.focus(at: CGPoint(x: normalizedY, y: 1 - normalizedX))
                        Task { try? await Task.sleep(for: .seconds(1.2)); focusPoint = nil }
                    }
            }.frame(height: height).clipped()
                .onAppear { previewAspect = max(0.3, (UIScreen.main.bounds.width - 50) / height) }
                .onChange(of: height) { _, value in previewAspect = max(0.3, (UIScreen.main.bounds.width - 50) / value) }
            HStack { Text("2.7\" PURE COLOR LCD"); Spacer(); Text(String(format: "%04d", garden.snapshot.moments)) }.font(.system(size: 6, design: .monospaced)).tracking(1.4).foregroundStyle(.white.opacity(0.45)).padding(.horizontal, 5).frame(height: 20)
        }.padding(8).background(Color(red: 0.19, green: 0.22, blue: 0.18), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.2), lineWidth: 1))
            .shadow(color: .white.opacity(0.8), radius: 1, y: 1)
    }

    private var filters: some View {
        HStack(spacing: 6) {
            ForEach(FilmLook.allCases) { option in
                Button { look = option; UISelectionFeedbackGenerator().selectionChanged() } label: {
                    VStack(spacing: 7) {
                        Capsule().fill(option == look ? Palette.moss : Palette.sage.opacity(0.18)).frame(height: 3)
                        Text(option.rawValue).font(.system(size: 10, weight: option == look ? .semibold : .regular))
                        
                    }.frame(maxWidth: .infinity).padding(.vertical, 5)
                }.foregroundStyle(option == look ? Palette.ink : .secondary).accessibilityAddTraits(option == look ? [.isSelected] : [])
            }
        }.padding(.top, 2)
    }

    private var captureControls: some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo.badge.plus").font(.system(size: 19)).frame(width: 49, height: 40)
                }.disabled(processing || camera.isCapturing || !garden.ready).accessibilityLabel("앨범 사진 불러오기")
                Button { sheet = .album } label: { Text("앨범").font(.system(size: 10)).frame(width: 49, height: 26) }.accessibilityLabel("앱 앨범 열기")
            }
            Spacer(minLength: 2)
            VStack(spacing: 7) {
                Button {
                    guard !processing else { return }
                    processing = true
                    let capturedLook = look, capturedMode = mode, stamp = dateStamp
                    camera.capture(flash: flash) { result in
                        switch result {
                        case .success(let data): Task { await process(data, look: capturedLook, mode: capturedMode, stamp: stamp) }
                        case .failure(let error): processing = false; notify(error.localizedDescription)
                        }
                    }
                } label: {
                    ZStack {
                        Circle().fill(Palette.cream).frame(width: 69, height: 69).overlay(Circle().stroke(Palette.sage.opacity(0.6), lineWidth: 1))
                        Circle().fill(Palette.moss).frame(width: 55, height: 55).shadow(color: .white.opacity(0.2), radius: 1, y: -1)
                        if processing || camera.isCapturing { ProgressView().tint(.white) }
                    }
                }.disabled(processing || camera.isCapturing || !camera.isRunning || !garden.ready).accessibilityLabel("사진 촬영")
                Menu {
                    ForEach(CaptureMode.allCases) { value in Button(value.title) { mode = value } }
                } label: { HStack(spacing: 4) { Text(mode.title); Image(systemName: "chevron.down").font(.system(size: 6)) }.font(.system(size: 9)) }.disabled(processing)
            }
            Spacer(minLength: 2)
            VStack(spacing: 0) {
                Button { camera.flip() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera").font(.system(size: 19)).frame(width: 49, height: 40) }.disabled(!camera.isRunning || processing).accessibilityLabel("앞뒤 카메라 전환")
                Menu {
                    ForEach([1.0, 1.5, 2.0, 3.0], id: \.self) { value in Button(String(format: "%.1f×", value)) { camera.setZoom(value) } }
                } label: { Text(String(format: "%.1f×", camera.zoom)).font(.system(size: 10, design: .monospaced)).frame(width: 49, height: 26) }.disabled(!camera.isRunning).accessibilityLabel("줌")
            }
        }.foregroundStyle(Palette.ink)
    }

    private var marimoAccessory: some View {
        Button { sheet = .garden } label: {
            HStack(spacing: 8) {
                MarimoView(size: 49, happy: processing)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) { Text(garden.snapshot.name).font(.system(size: 12, weight: .semibold)); Text("LV. \(garden.growth.level)").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.sage) }
                    Text(processing ? "네 순간을 맛보는 중…" : "오늘은 어떤 순간을 먹을까?").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(garden.growth.progress) / 100").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.sage)
                    ProgressView(value: Double(garden.growth.progress), total: 100).frame(width: 56).tint(Palette.sage)
                }
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Palette.sage).padding(.leading, 4)
            }.padding(.horizontal, 9).padding(.vertical, 4).background(Palette.cream.opacity(0.8), in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).foregroundStyle(Palette.ink).accessibilityLabel("\(garden.snapshot.name), 레벨 \(garden.growth.level), 마리모 열기")
    }

    @MainActor private func process(_ data: Data, look: FilmLook, mode: CaptureMode, stamp: Bool) async {
        defer { processing = false }
        do {
            let oldLevel = garden.growth.level
            let result = try await pipeline.process(data: data, look: look, mode: mode, dateStamp: stamp, aspectRatio: previewAspect)
            let gain = try await garden.add(result, filter: look, mode: mode)
            withAnimation(.easeOut(duration: 0.15)) { shutterFlash = true }
            Task { try? await Task.sleep(for: .milliseconds(160)); withAnimation { shutterFlash = false } }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            notify(garden.growth.level > oldLevel ? "무럭무럭! \(garden.snapshot.name)가 LV. \(garden.growth.level)이 됐어요 🌱" : "\(result.isFood ? "든든한 한 끼" : "작은 순간") · +\(gain) EXP")
            if autoSave {
                do { try await PhotoLibraryWriter.save(result.jpeg) }
                catch { notify("앱에는 저장했어요. \(error.localizedDescription)") }
            }
        } catch { notify("저장하지 못했어요. \(error.localizedDescription)") }
    }

    private func notify(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task { try? await Task.sleep(for: .seconds(4)); guard !Task.isCancelled else { return }; withAnimation { toast = nil } }
    }
}
