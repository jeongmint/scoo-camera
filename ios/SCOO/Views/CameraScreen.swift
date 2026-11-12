import SwiftUI
import UIKit
import PhotosUI

@MainActor
struct CameraScreen: View {
    @EnvironmentObject private var garden: GardenStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraService()
    @AppStorage("dateStamp") private var dateStamp = true
    @AppStorage("autoSave") private var autoSave = false
    @AppStorage("moriX") private var savedMoriX = MoriPlacement.initial.x
    @AppStorage("moriY") private var savedMoriY = MoriPlacement.initial.y
    @AppStorage("moriMoveHintSeen") private var moveHintSeen = false
    @State private var mode: CaptureMode = .auto
    @State private var flash = false
    @State private var processing = false
    @State private var shutterFlash = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var focusTask: Task<Void, Never>?
    @State private var focusPoint: CGPoint?
    @State private var sheet: CameraSheet?
    @State private var selectedItem: PhotosPickerItem?
    @State private var importing = false
    @State private var moving = false
    @State private var dragPoint: CGPoint?
    @GestureState private var dragSequenceActive = false
    @State private var pipeline = PhotoPipeline()

    private enum CameraSheet: String, Identifiable {
        case album, garden, settings
        var id: String { rawValue }
    }
    private let look = FilmLook.eternal
    private var blocked: Bool { processing || camera.isCapturing || !garden.ready }
    private var canCapture: Bool { !blocked && camera.isRunning && scenePhase == .active && sheet == nil }
    private var moriSize: CGFloat { min(105, 78 + CGFloat(sqrt(Double(max(0, garden.snapshot.experience)))) * 0.3) }

    var body: some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            let size = CGSize(width: geometry.size.width, height: geometry.size.height + insets.top + insets.bottom)
            ZStack {
                cameraFeed(size: size)
                LinearGradient(colors: [.black.opacity(0.40), .clear, .clear, .black.opacity(0.48)], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                if let focusPoint {
                    RoundedRectangle(cornerRadius: 3).stroke(.yellow.opacity(0.9), lineWidth: 1)
                        .frame(width: 54, height: 54).position(focusPoint).allowsHitTesting(false)
                }
                chrome(insets: insets)
                floatingMori(size: size, insets: insets)
                if shutterFlash { Color.white.opacity(0.8).allowsHitTesting(false) }
                if let toast {
                    Text(toast).font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(.black.opacity(0.65), in: Capsule()).foregroundStyle(.white)
                        .frame(maxWidth: min(340, size.width - 40))
                        .position(x: size.width / 2, y: geometry.safeAreaInsets.top + 118)
                        .allowsHitTesting(false).transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(name: "cameraViewport")
            .offset(y: -insets.top)
            .onChange(of: dragSequenceActive) { _, active in
                if active && !moving {
                    moving = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                if !active {
                    // Reset even if iOS cancels a drag (e.g. Control Center/background).
                    moving = false
                    dragPoint = nil
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .tint(.white)
        .task { camera.setLook(look); camera.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && sheet == nil && !importing { camera.start() }
            else { camera.stop(); focusTask?.cancel() }
        }
        .onChange(of: sheet) { _, value in if value != nil { camera.stop() } }
        .onChange(of: importing) { _, value in
            if value { camera.stop() }
            else if scenePhase == .active && sheet == nil { camera.start() }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            guard !processing else { selectedItem = nil; return }
            processing = true
            let capturedMode = mode, stamp = dateStamp
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw SCOOError.message("사진을 불러오지 못했어요.")
                    }
                    // Imported photos keep their original aspect ratio.
                    await process(data, mode: capturedMode, stamp: stamp, aspect: nil)
                } catch { processing = false; notify(error.localizedDescription) }
                selectedItem = nil
            }
        }
        .onChange(of: camera.errorMessage) { _, error in if let error { notify(error) } }
        .onChange(of: garden.message) { _, error in if let error { notify(error); garden.message = nil } }
        .onDisappear { camera.stop(); toastTask?.cancel(); focusTask?.cancel() }
        .sheet(item: $sheet, onDismiss: {
            if scenePhase == .active && !importing { camera.start() }
        }) { value in
            switch value {
            case .album: AlbumScreen().environmentObject(garden)
            case .garden: GardenScreen().environmentObject(garden)
            case .settings: SettingsScreen()
            }
        }
        .photosPicker(isPresented: $importing, selection: $selectedItem, matching: .images)
    }

    private func cameraFeed(size: CGSize) -> some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.09)
            if let frame = camera.frame {
                Image(uiImage: frame).resizable().scaledToFill()
                    .frame(width: size.width, height: size.height).clipped()
            }
            if !camera.isRunning {
                VStack(spacing: 17) {
                    Text("Eternal").font(.system(size: 38, weight: .regular, design: .serif)).italic()
                    Text(camera.permissionDenied ? "카메라를 허용하고\n모리에게 오늘을 보여 주세요." : "오늘의 순간을 기다리는 중.")
                        .font(.system(size: 13)).multilineTextAlignment(.center)
                    Button(camera.permissionDenied ? "설정에서 카메라 허용" : "카메라 켜기") {
                        if camera.permissionDenied, let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        else { camera.start() }
                    }.font(.caption).padding(.horizontal, 18).padding(.vertical, 11).background(.white.opacity(0.14), in: Capsule())
                    Button("사진 불러와서 체험하기") { importing = true }
                        .font(.caption2).disabled(blocked)
                }.foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size.width, height: size.height).clipped()
        .contentShape(Rectangle())
        .onTapGesture { point in focus(at: point, viewport: size) }
    }

    private func chrome(insets: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Eternal").font(.system(size: 25, weight: .regular, design: .serif)).italic()
                    .accessibilityLabel("Eternal 필터")
                Spacer()
                Button { flash.toggle() } label: {
                    Image(systemName: flash ? "bolt.fill" : "bolt.slash").frame(width: 44, height: 44)
                }.disabled(blocked || !camera.hasFlash).opacity(camera.hasFlash ? 1 : 0.35)
                    .accessibilityLabel(flash ? "플래시 끄기" : "플래시 켜기")
                Button { sheet = .settings } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                    .disabled(blocked).accessibilityLabel("설정")
            }.padding(.horizontal, 22)
            HStack(spacing: 8) {
                Button { sheet = .garden } label: {
                    Text("\(garden.snapshot.name)  ·  LV.\(garden.growth.level)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(.black.opacity(0.25), in: Capsule())
                }.disabled(blocked).accessibilityLabel("\(garden.snapshot.name) 성장 기록 열기")
                Spacer()
                Menu {
                    ForEach([1.0, 1.5, 2.0, 3.0], id: \.self) { value in
                        Button(String(format: "%.1f×", value)) { camera.setZoom(value) }
                    }
                } label: { Text(String(format: "%.1f×", camera.zoom)).font(.system(size: 12, design: .monospaced)).frame(width: 44, height: 32) }
                    .disabled(!camera.isRunning || blocked).accessibilityLabel("줌")
            }.padding(.horizontal, 22)
            Spacer(minLength: 0)
            if !moveHintSeen {
                Text("모리를 눌러 찰칵 · 꾹 누르고 끌어서 이동")
                    .font(.system(size: 10, weight: .medium)).padding(.bottom, 17)
                    .allowsHitTesting(false)
            }
            HStack {
                Menu {
                    Button("앱 앨범", systemImage: "photo.on.rectangle") { sheet = .album }
                    Button("사진 불러오기", systemImage: "photo.badge.plus") { importing = true }
                } label: { Image(systemName: "photo.on.rectangle").font(.system(size: 20)).frame(width: 48, height: 48) }
                    .disabled(blocked).accessibilityLabel("앨범과 사진 불러오기")
                Spacer()
                Menu {
                    ForEach(CaptureMode.allCases) { value in Button(value.title) { mode = value } }
                } label: {
                    HStack(spacing: 5) { Text(mode.title); Image(systemName: "chevron.down").font(.system(size: 8)) }
                        .font(.system(size: 11, weight: .medium)).padding(.horizontal, 15).frame(height: 38)
                        .background(.black.opacity(0.25), in: Capsule())
                }.disabled(blocked).accessibilityLabel("촬영 모드, \(mode.title)")
                Spacer()
                Button { camera.flip() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera").font(.system(size: 21)).frame(width: 48, height: 48)
                }.disabled(!camera.isRunning || blocked).accessibilityLabel("앞뒤 카메라 전환")
            }.padding(.horizontal, 22)
        }
        .padding(.top, insets.top + 10)
        .padding(.bottom, max(insets.bottom, 12) + 6)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    private func placement(_ candidate: MoriPlacement, size: CGSize, insets: EdgeInsets) -> CGPoint {
        let bounds = candidate.clamped(width: Double(size.width), height: Double(size.height),
                                       top: Double(insets.top + 80), bottom: Double(insets.bottom + 90),
                                       radius: Double(moriSize / 2))
        return CGPoint(x: CGFloat(bounds.x) * size.width, y: CGFloat(bounds.y) * size.height)
    }

    private func floatingMori(size: CGSize, insets: EdgeInsets) -> some View {
        let resting = placement(MoriPlacement(x: savedMoriX, y: savedMoriY), size: size, insets: insets)
        let current = dragPoint ?? resting
        let viewportAspect = size.width / max(1, size.height)
        let move = LongPressGesture(minimumDuration: 0.35, maximumDistance: 18)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("cameraViewport")))
            .updating($dragSequenceActive) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, let drag) = value, let drag else { return }
                // Use translation from the resting center, not the finger location: no jump on pickup.
                let candidate = MoriPlacement(x: Double((resting.x + drag.translation.width) / max(1, size.width)),
                                              y: Double((resting.y + drag.translation.height) / max(1, size.height)))
                dragPoint = placement(candidate, size: size, insets: insets)
            }
            .onEnded { value in
                if case .second(true, let drag) = value, let drag {
                    let candidate = MoriPlacement(x: Double((resting.x + drag.translation.width) / max(1, size.width)),
                                                  y: Double((resting.y + drag.translation.height) / max(1, size.height)))
                    let end = placement(candidate, size: size, insets: insets)
                    savedMoriX = Double(end.x / max(1, size.width))
                    savedMoriY = Double(end.y / max(1, size.height))
                    moveHintSeen = true
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                moving = false
                dragPoint = nil
            }
        let tap = TapGesture().onEnded { takePhoto(aspect: viewportAspect) }
        return ZStack {
            MarimoView(size: moriSize, happy: processing || camera.isCapturing, floats: !moving)
                .shadow(color: .black.opacity(0.35), radius: 9, y: 7)
            if processing || camera.isCapturing { ProgressView().tint(.white).scaleEffect(0.75) }
            if moving {
                Text("여기에 둘까?").font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule()).foregroundStyle(.white)
                    .offset(y: -moriSize / 2 - 12).allowsHitTesting(false)
            }
        }
        .frame(width: moriSize, height: moriSize)
        .contentShape(Circle())
        .scaleEffect(moving ? 1.10 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: moving)
        .gesture(move.exclusively(before: tap))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(garden.snapshot.name), 사진 촬영")
        .accessibilityValue("레벨 \(garden.growth.level)")
        .accessibilityHint("두 번 탭하면 촬영합니다. 화면에서 꾹 누르고 끌면 이동합니다.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { takePhoto(aspect: viewportAspect) }
        .accessibilityAction(named: "중앙 아래로 이동") {
            savedMoriX = MoriPlacement.initial.x
            savedMoriY = MoriPlacement.initial.y
        }
        .position(current)
    }

    private func takePhoto(aspect: CGFloat) {
        guard canCapture else {
            if !camera.isRunning { notify("카메라를 켜면 모리를 눌러 촬영할 수 있어요.") }
            return
        }
        processing = true
        let capturedMode = mode, stamp = dateStamp
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        camera.capture(flash: flash) { result in
            switch result {
            case .success(let data): Task { await process(data, mode: capturedMode, stamp: stamp, aspect: aspect) }
            case .failure(let error): processing = false; notify(error.localizedDescription)
            }
        }
    }

    private func focus(at point: CGPoint, viewport: CGSize) {
        guard camera.isRunning, !moving else { return }
        focusTask?.cancel()
        focusPoint = point
        let source = camera.frame?.size ?? CGSize(width: 3, height: 4)
        let scale = max(viewport.width / source.width, viewport.height / source.height)
        let x = (point.x + (source.width * scale - viewport.width) / 2) / (source.width * scale)
        let y = (point.y + (source.height * scale - viewport.height) / 2) / (source.height * scale)
        camera.focus(at: CGPoint(x: min(1, max(0, y)), y: min(1, max(0, 1 - x))))
        focusTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            focusPoint = nil
        }
    }

    private func process(_ data: Data, mode: CaptureMode, stamp: Bool, aspect: CGFloat?) async {
        defer { processing = false }
        do {
            let oldLevel = garden.growth.level
            let result = try await pipeline.process(data: data, look: look, mode: mode, dateStamp: stamp, aspectRatio: aspect)
            let gain = try await garden.add(result, filter: look, mode: mode)
            withAnimation(.easeOut(duration: 0.12)) { shutterFlash = true }
            Task { try? await Task.sleep(for: .milliseconds(160)); withAnimation { shutterFlash = false } }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            notify(garden.growth.level > oldLevel
                   ? "\(garden.snapshot.name), LV.\(garden.growth.level)! 또 자랐어 🌱"
                   : "\(result.isFood ? "냠냠, 든든한 한 끼" : "이 순간 마음에 들어") · +\(gain) EXP")
            if autoSave {
                do { try await PhotoLibraryWriter.save(result.jpeg) }
                catch { notify("앱에는 저장했어요. \(error.localizedDescription)") }
            }
        } catch { notify("저장하지 못했어요. \(error.localizedDescription)") }
    }

    private func notify(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { toast = nil }
        }
    }
}
