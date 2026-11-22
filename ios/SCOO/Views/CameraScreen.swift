import SwiftUI
import UIKit
import PhotosUI
import MetalKit

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
    @AppStorage("assignedCompanion") private var assignedRaw = ""
    @AppStorage("district") private var districtRaw = ""
    @StateObject private var locator = DistrictLocator()
    @AppStorage("companion") private var companionRaw = ""
    @ObservedObject private var friends = FriendStore.shared
    /// Bred babies, which can float too (and then grow by themselves).
    @StateObject private var babies = BreedStore()
    /// Whether the floating friend is also drawn into the photo, or only floats on screen.
    @AppStorage("companionInPhoto") private var companionInPhoto = true
    /// Leave each photo's spot on the map guestbook.
    @AppStorage("savePlace") private var savePlace = true
    /// The day (yyyy-MM-dd) the daily mission was last completed.
    @AppStorage("missionDoneDay") private var missionDoneDay = ""
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
    @GestureState private var pressActive = false
    @State private var holdTask: Task<Void, Never>?
    @State private var pipeline = PhotoPipeline()
    /// A friend met on the first photo in a new district (동네 탐험).
    @State private var newFriend: NewFriend?
    @State private var expression: MoriExpression = .normal
    @State private var expressionTask: Task<Void, Never>?
    @State private var lastReaction: MoriExpression?
    /// Voice talk mode (음성 대화, 티키타카).
    @StateObject private var talk = PetTalkSession()
    /// Talk replies from the server (text only); off = built-in lines only.
    @AppStorage("talkOnline") private var talkOnline = true
    /// 주변 친구: share a rounded position with friends and show theirs on the camera (off by default).
    @AppStorage("friendRadar") private var friendRadarOn = false
    @StateObject private var radar = FriendRadar()

    private enum CameraSheet: String, Identifiable {
        case album, garden, settings, map
        var id: String { rawValue }
    }
    private let look = FilmLook.eternal
    private var blocked: Bool { processing || camera.isCapturing || !garden.ready }
    private var canCapture: Bool { !blocked && camera.isRunning && scenePhase == .active && sheet == nil }
    /// The friend this user was randomly handed on first launch, and the friends they can shoot with
    /// (that one plus any open event friend such as the snowman).
    /// The characters this user has; any of them can float in Mori's place.
    private var ownedCompanions: [Species] { friends.species }
    /// Who floats in Mori's place: a friend or a bred baby; nil = 기본 모리 (also when the picked one left).
    private var floater: Floater? { Floater.resolve(companionRaw, owns: { friends.owns($0) }, babies: babies.breeds) }
    /// The floating friend, when it is a character (not a baby).
    private var companion: Species? { floater?.species }
    /// The floating one's own EXP: the picked friend's or baby's, or 기본 모리's. Everyone grows by themselves.
    private var heroXP: Int {
        switch floater {
        case .friend(let species): return friends.friend(for: species.id)?.xp ?? 0
        case .baby(let baby): return baby.xp(moments: garden.snapshot.moments)
        case nil: return garden.snapshot.experience
        }
    }
    private var heroGrowth: Growth { GrowthRules.growth(for: heroXP) }
    private var heroName: String { floater?.name ?? garden.snapshot.name }
    /// The floating one's picture for drawing into the photo (babies are rendered from their portrait).
    private func sticker() -> UIImage? {
        switch floater {
        case .friend(let species): return UIImage(named: species.assetName)
        case .baby(let baby):
            let renderer = ImageRenderer(content: BreedPortrait(breed: baby, stage: baby.stage(moments: garden.snapshot.moments))
                .frame(width: 600, height: 600))
            renderer.scale = 1
            return renderer.uiImage
        case nil: return nil
        }
    }
    /// Babies from before they grew by floating keep what they grew; then the list is fresh for the menu.
    private func refreshBabies() {
        if garden.ready { babies.freezeLegacy(moments: garden.snapshot.moments) } else { babies.load() }
    }
    private var moriSize: CGFloat { min(105, 78 + CGFloat(sqrt(Double(max(0, heroXP)))) * 0.3) }
    /// Who answers in talk mode: the floating friend, with the personality grown from the photos.
    private var talkPet: TalkPet {
        let personality = Personality.of(garden.snapshot.photos).title
        if let baby = floater?.baby { return TalkPet.of(baby: baby, personality: personality) }
        return TalkPet.of(companion, moriName: garden.snapshot.name, personality: personality)
    }
    /// While talking, the friend wears the face of what it says.
    private var face: MoriExpression { talk.phase == .speaking ? talk.mood : expression }

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
                if talk.isOn { TalkGlow(color: talkPet.color, level: talk.level, phase: talk.phase).transition(.opacity) }
                if radar.isOn { RadarOverlay(blips: radar.blips, heading: radar.heading, size: size, insets: insets) }
                chrome(insets: insets)
                floatingMori(size: size, insets: insets)
                if talk.isOn { talkBubble(size: size, insets: insets) }
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
            .onChange(of: pressActive) { _, active in
                holdTask?.cancel()
                if active {
                    // Holding still for a moment picks Mori up; a quick tap never gets here.
                    holdTask = Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        guard !Task.isCancelled else { return }
                        moving = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                } else {
                    // Reset even if iOS cancels a drag (e.g. Control Center/background).
                    holdTask = nil
                    moving = false
                    dragPoint = nil
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .tint(.white)
        .task {
            if friendRadarOn { radar.start() }
            camera.setLook(look); camera.start()
            await meetFriend()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && sheet == nil && !importing { camera.start() }
            else { camera.stop(); focusTask?.cancel(); talk.stop(); radar.stop() }
            if phase == .active && sheet == nil && friendRadarOn { radar.start() }
        }
        .onChange(of: sheet) { _, value in
            if value != nil { camera.stop(); talk.stop(); radar.stop() }
            else if friendRadarOn && scenePhase == .active { radar.start() }
        }
        .onChange(of: friendRadarOn) { _, on in
            if on {
                radar.start()
                notify("주변 친구 보기를 켰어요. 친구에게만 내 대략 위치(100m 단위)가 보이고, 끄면 바로 지워져요.")
            } else { radar.stop() }
        }
        .onChange(of: radar.problem) { _, problem in if let problem { notify(problem); radar.problem = nil; friendRadarOn = radar.isOn } }
        .onChange(of: importing) { _, value in
            if value { camera.stop() }
            else if scenePhase == .active && sheet == nil { camera.start() }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            guard !processing else { selectedItem = nil; return }
            processing = true
            closeEyes()
            let capturedMode = mode, stamp = dateStamp, together = companionInPhoto ? sticker() : nil
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw SCOOError.message("사진을 불러오지 못했어요.")
                    }
                    // Imported photos keep their original aspect ratio.
                    // Imported photos keep their own size; use the saved floating spot at a standard size.
                    let spot = CompanionSpot(center: CGPoint(x: savedMoriX, y: savedMoriY), width: CompanionSpot.defaultWidth)
                    // Imported photos land on the map where they were taken, if they carry GPS.
                    let place = savePlace ? PhotoLocation.fromImageData(data) : nil
                    await process(data, mode: capturedMode, stamp: stamp, aspect: nil, sticker: together, spot: spot, place: place)
                } catch { processing = false; calmDown(); notify(error.localizedDescription) }
                selectedItem = nil
            }
        }
        .onChange(of: camera.errorMessage) { _, error in if let error { notify(error) } }
        .onChange(of: garden.message) { _, error in if let error { notify(error); garden.message = nil } }
        .onDisappear { camera.stop(); toastTask?.cancel(); focusTask?.cancel(); expressionTask?.cancel(); talk.stop(); radar.stop() }
        .onChange(of: talk.problem) { _, problem in if let problem { notify(problem); talk.problem = nil } }
        .onChange(of: companionRaw) { _, _ in talk.update(talkPet) }
        .animation(.easeInOut(duration: 0.35), value: talk.isOn)
        .onChange(of: assignedRaw) { _, _ in WidgetBridge.refresh() }
        .onChange(of: companionRaw) { _, _ in WidgetBridge.refresh() }
        .onAppear { refreshBabies() }
        .onChange(of: garden.ready) { _, _ in refreshBabies() }
        .onChange(of: sheet == nil) { _, closed in if closed { refreshBabies() } }
        .sheet(item: $newFriend) { meeting in NewFriendSheet(meeting: meeting) }
        .sheet(item: $sheet, onDismiss: {
            if scenePhase == .active && !importing { camera.start() }
        }) { value in
            switch value {
            case .album: AlbumScreen().environmentObject(garden)
            case .garden: GardenScreen().environmentObject(garden)
            case .settings: SettingsScreen().presentationBackground(.ultraThinMaterial).preferredColorScheme(.dark)
            case .map: PlaceMapScreen().environmentObject(garden)
            }
        }
        .photosPicker(isPresented: $importing, selection: $selectedItem, matching: .images)
    }

    private func cameraFeed(size: CGSize) -> some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.09)
            CameraPreview(renderer: camera.preview)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
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
                Button { toggleTalk() } label: {
                    Image(systemName: talk.isOn ? "waveform.circle.fill" : "bubble.left.and.text.bubble.right")
                        .symbolEffect(.variableColor.iterative, isActive: talk.phase == .listening)
                        .frame(width: 44, height: 44)
                }.disabled(!garden.ready)
                    .accessibilityLabel(talk.isOn ? "대화 끝내기" : "\(talkPet.name)랑 이야기하기")
                Button { flash.toggle() } label: {
                    Image(systemName: flash ? "bolt.fill" : "bolt.slash").frame(width: 44, height: 44)
                }.disabled(blocked || !camera.hasFlash).opacity(camera.hasFlash ? 1 : 0.35)
                    .accessibilityLabel(flash ? "플래시 끄기" : "플래시 켜기")
                Button { sheet = .settings } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                    .disabled(blocked).accessibilityLabel("설정")
            }.padding(.horizontal, 22)
            HStack(spacing: 8) {
                Button { sheet = .garden } label: {
                    Text("\(heroName)  ·  LV.\(heroGrowth.level)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(.black.opacity(0.25), in: Capsule())
                }.disabled(blocked).accessibilityLabel("\(heroName) 성장 기록 열기")
                missionChip
                Spacer()
                Menu {
                    ForEach([1.0, 1.2, 1.5, 2.0, 3.0], id: \.self) { value in
                        Button(String(format: "%.1f×", value)) { camera.setZoom(value) }
                    }
                } label: { Text(String(format: "%.1f×", camera.zoom)).font(.system(size: 12, design: .monospaced)).frame(width: 44, height: 32) }
                    .disabled(!camera.isRunning || blocked).accessibilityLabel("줌")
            }.padding(.horizontal, 22)
            Spacer(minLength: 0)
            if !moveHintSeen {
                Text("모리를 눌러 찰칵 · 아래로 쓸면 동영상 · 꾹 눌러 이동 · 말풍선을 누르면 대화")
                    .font(.system(size: 10, weight: .medium)).padding(.bottom, 17)
                    .allowsHitTesting(false)
            }
            HStack {
                Menu {
                    Button("앱 앨범", systemImage: "photo.on.rectangle") { sheet = .album }
                    Button("지도 방명록", systemImage: "map") { sheet = .map }
                    Button("사진 불러오기", systemImage: "photo.badge.plus") { importing = true }
                } label: { Image(systemName: "photo.on.rectangle").font(.system(size: 20)).frame(width: 48, height: 48) }
                    .disabled(blocked).accessibilityLabel("앨범과 사진 불러오기")
                Spacer()
                Menu {
                    ForEach(CaptureMode.allCases) { value in Button(value.title) { mode = value } }
                    Section("떠 있는 친구") {
                        Picker("떠 있는 친구", selection: $companionRaw) {
                            Text("기본 모리").tag("")
                            ForEach(ownedCompanions) { friend in Text(friend.menuTitle).tag(friend.id) }
                            ForEach(babies.breeds) { baby in Text("아기 · \(baby.title)").tag(Floater.tag(baby)) }
                        }
                    }
                    Section {
                        Toggle("주변 친구 보기", isOn: $friendRadarOn)
                    } footer: {
                        Text("친구에게만 내 대략 위치가 보여요.")
                    }
                    if floater != nil {
                        Section {
                            Toggle("사진에 같이 찍기", isOn: $companionInPhoto)
                        } footer: {
                            Text(companionInPhoto ? "떠 있는 자리 그대로 사진에 함께 담겨요." : "화면에만 떠 있고 사진에는 안 찍혀요.")
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(floater.map { "\(mode.title) · \($0.name)" } ?? mode.title)
                        if floater != nil && companionInPhoto {
                            Image(systemName: "camera.fill").font(.system(size: 8))
                        }
                        Image(systemName: "chevron.down").font(.system(size: 8))
                    }
                        .font(.system(size: 11, weight: .medium)).padding(.horizontal, 15).frame(height: 38)
                        .background(.black.opacity(0.25), in: Capsule())
                }.disabled(blocked)
                    .accessibilityLabel("촬영 모드, \(mode.title), \(floater.map { "\($0.name), " + (companionInPhoto ? "사진에 같이 찍기" : "화면에만") } ?? "기본 모리")")
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

    /// A small chip with today's mission; it turns into a check once done.
    private var missionChip: some View {
        let mission = DailyMission.of(Date())
        let done = missionDoneDay == DailyMission.dayKey(Date())
        return Button {
            notify(done ? "오늘의 미션 완료! 내일 또 새 미션이 와요."
                        : "오늘의 미션은 ‘\(mission.title)’! 찍으면 +\(DailyMission.bonus) EXP를 더 받아요.")
        } label: {
            HStack(spacing: 4) {
                Image(systemName: done ? "checkmark.circle.fill" : mission.systemImage)
                Text(done ? "미션 완료" : mission.title)
            }
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.black.opacity(0.25), in: Capsule())
        }
        .disabled(blocked)
        .accessibilityLabel(done ? "오늘의 미션 완료" : "오늘의 미션, \(mission.title)")
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
        // The picked friend is drawn into the photo exactly where and as big as it floats.
        let spot = CompanionSpot(center: CGPoint(x: resting.x / max(1, size.width), y: resting.y / max(1, size.height)),
                                 width: moriSize / max(1, size.width))
        let slop: CGFloat = 18
        // One gesture decides everything: short press = shutter, hold then drag = move.
        let press = DragGesture(minimumDistance: 0, coordinateSpace: .named("cameraViewport"))
            .updating($pressActive) { _, state, _ in state = true }
            .onChanged { value in
                if moving {
                    // Use translation from the resting center, not the finger location: no jump on pickup.
                    let candidate = MoriPlacement(x: Double((resting.x + value.translation.width) / max(1, size.width)),
                                                  y: Double((resting.y + value.translation.height) / max(1, size.height)))
                    dragPoint = placement(candidate, size: size, insets: insets)
                } else if hypot(value.translation.width, value.translation.height) > slop {
                    holdTask?.cancel()   // a swipe, not a hold
                }
            }
            .onEnded { value in
                holdTask?.cancel()
                if moving {
                    let candidate = MoriPlacement(x: Double((resting.x + value.translation.width) / max(1, size.width)),
                                                  y: Double((resting.y + value.translation.height) / max(1, size.height)))
                    let end = placement(candidate, size: size, insets: insets)
                    savedMoriX = Double(end.x / max(1, size.width))
                    savedMoriY = Double(end.y / max(1, size.height))
                    moveHintSeen = true
                    UISelectionFeedbackGenerator().selectionChanged()
                } else if hypot(value.translation.width, value.translation.height) <= slop {
                    // a tap: take a photo, or stop the video that is running
                    if camera.isRecording { camera.stopRecording() } else { takePhoto(aspect: viewportAspect, spot: spot) }
                } else if abs(value.translation.height) > abs(value.translation.width) {
                    // a quick vertical swipe: down starts a video, up stops it
                    if value.translation.height > 50, !camera.isRecording { startVideo() }
                    else if value.translation.height < -50, camera.isRecording { camera.stopRecording() }
                }
                moving = false
                dragPoint = nil
            }
        return ZStack {
            Group {
                if let companion {
                    FloatingFriend(size: moriSize, expression: face, floats: !moving) {
                        Image(companion.assetName).resizable().scaledToFit()
                    }
                } else if let baby = floater?.baby {
                    FloatingFriend(size: moriSize, expression: face, floats: !moving) {
                        BreedPortrait(breed: baby, stage: baby.stage(moments: garden.snapshot.moments))
                    }
                } else {
                    MarimoView(size: moriSize, happy: processing || camera.isCapturing,
                               expression: face == .normal ? nil : face, floats: !moving)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 9, y: 7)
            if processing || camera.isCapturing { ProgressView().tint(.white).scaleEffect(0.75) }
            if camera.isRecording, let started = camera.recordingStarted {
                Circle().stroke(.red.opacity(0.9), lineWidth: 3).frame(width: moriSize + 10, height: moriSize + 10)
                    .allowsHitTesting(false)
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text(timerInterval: started...started.addingTimeInterval(ClipWriter.maxSeconds), countsDown: false)
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.black.opacity(0.55), in: Capsule()).foregroundStyle(.white)
                .offset(y: -moriSize / 2 - 16).allowsHitTesting(false)
            }
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
        .gesture(press)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(heroName), 사진 촬영")
        .accessibilityValue("레벨 \(heroGrowth.level)")
        .accessibilityHint("두 번 탭하면 촬영합니다. 화면에서 꾹 누르고 끌면 이동합니다.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { takePhoto(aspect: viewportAspect, spot: spot) }
        .accessibilityAction(named: camera.isRecording ? "동영상 멈추기" : "동영상 찍기") {
            if camera.isRecording { camera.stopRecording() } else { startVideo() }
        }
        .accessibilityAction(named: "중앙 아래로 이동") {
            savedMoriX = MoriPlacement.initial.x
            savedMoriY = MoriPlacement.initial.y
        }
        .position(current)
    }

    private func takePhoto(aspect: CGFloat, spot: CompanionSpot) {
        guard canCapture else {
            if !camera.isRunning { notify("카메라를 켜면 모리를 눌러 촬영할 수 있어요.") }
            else if !garden.ready { notify("모리가 아직 준비 중이에요. 잠시 후 다시 눌러 주세요.") }
            return
        }
        processing = true
        closeEyes()
        let capturedMode = mode, stamp = dateStamp, together = companionInPhoto ? sticker() : nil
        // Look up where we are while the shutter works, so the photo does not wait for GPS.
        let placeLookup: Task<PhotoLocation?, Never>? = savePlace ? Task { await locator.quickLocation() } : nil
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        camera.capture(flash: flash) { result in
            switch result {
            case .success(let data): Task {
                let place = await placeLookup?.value
                await process(data, mode: capturedMode, stamp: stamp, aspect: aspect, sticker: together, spot: spot, place: place)
            }
            case .failure(let error): processing = false; calmDown(); notify(error.localizedDescription)
            }
        }
    }

    /// First launch: one of the 5 characters of the 시군구 the user is in, at random.
    /// Without a usable position (permission, signal, outside Korea) a random place's 5 are used.
    private func meetFriend() async {
        guard !friends.hasStarter else { return }
        var generator = SystemRandomNumberGenerator()
        switch await locator.currentRegion() {
        case .success(let region):
            let friend = region.drawStarter(using: &generator)
            start(with: friend, region: region)
            newFriend = NewFriend(species: friend, region: region, kind: .starter)
        case .failure(let failure):
            let friend = Regions.randomStarter(using: &generator)
            start(with: friend, region: nil)
            notify("첫 친구 도착! \(friend.name) · \(failure.reason) 이번엔 랜덤으로 왔어요.")
        }
    }

    private func start(with friend: Species, region: Region?) {
        districtRaw = region?.id ?? ""
        assignedRaw = friend.id
        friends.setStarter(friend, origin: region?.title)
        for event in Species.openEvents() where !friends.owns(event) {
            if let species = Species.find(event) { friends.add(species, how: .event, origin: nil) }
        }
    }

    // MARK: Talk (음성 대화)

    private func toggleTalk() {
        if talk.isOn {
            talk.stop()
            return
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        talk.useServer = talkOnline
        let pet = talkPet
        notify("\(pet.name)랑 이야기 중 · 말풍선을 다시 누르면 끝나요")
        Task { await talk.start(pet) }
    }

    /// The bubble sits above the friend, kept on screen; when the friend floats near the top it goes below.
    private func talkBubble(size: CGSize, insets: EdgeInsets) -> some View {
        let spot = placement(MoriPlacement(x: savedMoriX, y: savedMoriY), size: size, insets: insets)
        let above = spot.y - moriSize / 2 - 56 > insets.top + 110
        return TalkBubble(name: talkPet.name, phase: talk.phase, heard: talk.heard, reply: talk.reply, color: talkPet.color)
            .frame(width: min(260, size.width - 32))
            .position(x: min(max(spot.x, 146), size.width - 146),
                      y: above ? spot.y - moriSize / 2 - 50 : spot.y + moriSize / 2 + 50)
            .allowsHitTesting(false)
    }

    // MARK: Video

    /// Swipe down on the floating friend: a short silent video with the Eternal look, up to 15 seconds.
    private func startVideo() {
        guard canCapture else {
            if !camera.isRunning { notify("카메라를 켜면 아래로 쓸어서 동영상을 찍을 수 있어요.") }
            return
        }
        let capturedMode = mode
        let placeLookup: Task<PhotoLocation?, Never>? = savePlace ? Task { await locator.quickLocation() } : nil
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        camera.startRecording { result in
            switch result {
            case .success(let clip):
                Task {
                    let place = await placeLookup?.value
                    await keepClip(clip, mode: capturedMode, place: place)
                }
            case .failure(let error):
                notify(error.localizedDescription)
            }
        }
    }

    private func keepClip(_ clip: ClipWriter.Clip, mode: CaptureMode, place: PhotoLocation?) async {
        processing = true
        defer { processing = false }
        let moment = ProcessedPhoto(jpeg: clip.poster, isFood: false, bonus: 0,
                                    classificationNote: "동영상 \(max(1, Int(clip.seconds.rounded())))초")
        do {
            let gain = try await garden.add(moment, filter: look, mode: mode, location: place, video: clip.url, friend: floater?.tag)
            babies.load()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            react(.smile)
            notify("움직이는 순간도 냠! · +\(gain) EXP")
            if autoSave, let stored = garden.snapshot.photos.first, let url = garden.videoURL(for: stored) {
                do { try await PhotoLibraryWriter.saveVideo(url) }
                catch { notify("앱에는 저장했어요. \(error.localizedDescription)") }
            }
        } catch {
            try? FileManager.default.removeItem(at: clip.url)
            notify("동영상을 저장하지 못했어요. \(error.localizedDescription)")
        }
    }

    // MARK: Expressions — 평소 미소 → 찰칵(눈감기) → 사진에 맞는 반응 → 평소 미소

    private func closeEyes() {
        expressionTask?.cancel()
        expression = .shutter
    }

    private func calmDown() {
        expressionTask?.cancel()
        expression = .normal
    }

    private func react(_ face: MoriExpression) {
        expressionTask?.cancel()
        lastReaction = face
        expression = face
        expressionTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            expression = .normal
        }
    }

    private func focus(at point: CGPoint, viewport: CGSize) {
        guard camera.isRunning, !moving else { return }
        focusTask?.cancel()
        focusPoint = point
        let source = CGSize(width: 3, height: 4)   // portrait photo-preset feed
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

    private func process(_ data: Data, mode: CaptureMode, stamp: Bool, aspect: CGFloat?, sticker: UIImage?, spot: CompanionSpot,
                         place: PhotoLocation?) async {
        defer { processing = false }
        do {
            // The floating friend grows (even when it is not drawn into the photo).
            let floating = self.floater
            let oldLevel = heroGrowth.level
            let result = try await pipeline.process(data: data, look: look, mode: mode, dateStamp: stamp, aspectRatio: aspect, sticker: sticker, spot: spot)
            let mission = DailyMission.of(Date())
            let missionHit = missionDoneDay != DailyMission.dayKey(Date()) && mission.matches(result.labels)
            let gain = try await garden.add(result, filter: look, mode: mode, location: place, extra: missionHit ? DailyMission.bonus : 0,
                                            friend: floating?.tag)
            babies.load()
            let newLevel = heroGrowth.level
            let stageUp = floating != nil && FriendGrowth.stage(level: newLevel) > FriendGrowth.stage(level: oldLevel)
            if missionHit { missionDoneDay = DailyMission.dayKey(Date()) }
            // Babies this user adopted write home about what they saw: only the subject word leaves the phone.
            let subjects = LetterWords.subjects(labels: result.labels, isFood: result.isFood)
            if !subjects.isEmpty { Task { await LetterWords.share(subjects) } }
            react(MoriExpression.reaction(isFood: result.isFood, bonus: result.bonus, leveledUp: newLevel > oldLevel,
                                          previous: lastReaction, roll: .random(in: 0..<1)))
            withAnimation(.easeOut(duration: 0.12)) { shutterFlash = true }
            Task { try? await Task.sleep(for: .milliseconds(160)); withAnimation { shutterFlash = false } }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if missionHit {
                notify("오늘의 미션 성공! \(mission.title) 찰칵 · +\(gain) EXP (미션 +\(DailyMission.bonus))")
            } else {
            notify(stageUp
                   ? "\(LetterWords.withSubject(heroName)) \(FriendGrowth.stage(level: newLevel) == .bloom ? "활짝 만개했어! 이제 교배할 수 있어요 🌼" : "성장기에 들어섰어! 🌿")"
                   : newLevel > oldLevel
                   ? "\(heroName), LV.\(newLevel)! 또 자랐어 🌱"
                   : "\(floating.map { "\($0.name)랑 같이 찰칵! " } ?? "")\(result.isFood ? "냠냠, 든든한 한 끼" : "이 순간 마음에 들어") · +\(gain) EXP")
            }
            if autoSave {
                do { try await PhotoLibraryWriter.save(result.jpeg) }
                catch { notify("앱에는 저장했어요. \(error.localizedDescription)") }
            }
            if let place { await explore(place) }
        } catch { calmDown(); notify("저장하지 못했어요. \(error.localizedDescription)") }
    }

    /// 동네 탐험: the first photo in a 시군구 not visited yet stamps it in the collection.
    /// New characters come only from glass bottles (adopted, or brought by the sea).
    private func explore(_ place: PhotoLocation) async {
        guard let region = await locator.region(at: place), Exploration.record(region) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        notify("\(region.title) 첫 방문 도장! 도감에 찍혔어요. (\(Exploration.load().visited.count)/\(Regions.all.count))")
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

private struct CameraPreview: UIViewRepresentable {
    let renderer: PreviewRenderer
    func makeUIView(context: Context) -> MTKView { renderer.makeView() }
    func updateUIView(_ view: MTKView, context: Context) { }
}

/// A picked friend floating in Mori's place. PNG friends have no drawn faces, so they react with their body:
/// a small squish while the photo is taken and a hop when it reacts.
private struct FloatingFriend<Picture: View>: View {
    let size: CGFloat
    let expression: MoriExpression
    var floats = true
    @ViewBuilder let picture: () -> Picture
    @State private var floating = false

    private var reacting: Bool { expression != .normal && expression != .shutter }

    var body: some View {
        picture()
            .frame(width: size, height: size)
            .scaleEffect(x: expression == .shutter ? 1.05 : 1, y: expression == .shutter ? 0.93 : 1, anchor: .bottom)
            .scaleEffect(reacting ? 1.08 : 1)
            .offset(y: reacting ? -size * 0.08 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: expression)
            .offset(y: floats ? (floating ? -4 : 3) : 0)
            .rotationEffect(.degrees(floats ? (floating ? 2 : -2) : 0))
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: floating)
            .onAppear { floating = true }
    }
}

struct NewFriend: Identifiable {
    enum Kind { case starter, sea, adopted }
    let species: Species
    let region: Region?
    var kind: Kind = .starter
    var id: String { species.id }
}

/// Shown when the first photo in a new district meets someone.
private struct NewFriendSheet: View {
    let meeting: NewFriend
    @Environment(\.dismiss) private var dismiss

    private var heading: String {
        switch meeting.kind {
        case .starter: return meeting.region.map { "\($0.title)에서 시작해요" } ?? "반가워요"
        case .sea: return "바다에서 떠내려왔어요"
        case .adopted: return "유리병을 타고 왔어요"
        }
    }
    var body: some View {
        VStack(spacing: 16) {
            Text(heading).font(.subheadline).foregroundStyle(.secondary)
            SpeciesPortrait(species: meeting.species).frame(width: 200, height: 200)
            Text(meeting.kind == .starter ? "첫 친구, \(meeting.species.name)" : "새 친구, \(meeting.species.name)")
                .font(.title3.weight(.semibold))
            if let region = meeting.region, meeting.kind == .starter {
                HStack(spacing: 6) {
                    ForEach(region.candidateSpecies) { other in
                        SpeciesPortrait(species: other).frame(width: 34, height: 34)
                            .opacity(other.id == meeting.species.id ? 1 : 0.35)
                    }
                }
                Text("\(region.title)의 다섯 친구 중 하나가 왔어요").font(.caption).foregroundStyle(.secondary)
            }
            Text(meeting.kind == .starter
                 ? "더 많은 친구는 유리병 입양으로 만나요. 하루 한 번 친구를 띄우면 다음 날 누군가의 친구나 바다의 새 친구가 와요."
                 : "친구 도감에 들어갔고, 이제 교배할 때 부모로 고를 수 있어요.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("반가워!") { dismiss() }
                .font(.headline).padding(.horizontal, 36).padding(.vertical, 12)
                .background(Palette.moss, in: Capsule()).foregroundStyle(.white)
        }
        .padding(28)
        .foregroundStyle(Palette.ink)
        .presentationDetents([.medium])
        .presentationBackground(Palette.cream)
    }
}
