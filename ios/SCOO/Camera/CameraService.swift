import AVFoundation
import CoreImage
import UIKit
import Combine
import MetalKit

/// All AVCaptureSession mutations run on sessionQueue; frame processing has its own queue.
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isCapturing = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var zoom: CGFloat = 1
    @Published private(set) var hasFlash = false

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "scoo.camera.session", qos: .userInitiated)
    private let frameQueue = DispatchQueue(label: "scoo.camera.frames", qos: .userInitiated)
    /// Draws the filtered live feed on the GPU; frames never touch SwiftUI state.
    let preview = PreviewRenderer()
    private let lookLock = NSLock()
    private var selectedLook: FilmLook = .eternal
    private var captureCompletion: ((Result<Data, Error>) -> Void)?
    private var input: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    private var configured = false
    private var wantsRunning = false
    private var runtimeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var interruptionEndedObserver: NSObjectProtocol?

    override init() {
        super.init()
        runtimeObserver = NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
            self.sessionQueue.async {
                if error?.code == .mediaServicesWereReset && self.wantsRunning {
                    self.session.startRunning()
                    self.publishRunning()
                } else {
                    self.fail(error?.localizedDescription ?? "카메라가 중단됐어요. 다시 켜 주세요.")
                }
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { self?.isRunning = false }
        }
        interruptionEndedObserver = NotificationCenter.default.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.sessionQueue.async {
                if self.wantsRunning { self.session.startRunning(); self.publishRunning() }
            }
        }
    }

    deinit {
        [runtimeObserver, interruptionObserver, interruptionEndedObserver].compactMap { $0 }.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func setLook(_ look: FilmLook) {
        lookLock.lock(); selectedLook = look; lookLock.unlock()
    }

    func start() {
        sessionQueue.async { self.wantsRunning = true }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: startAuthorized()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                if allowed { self?.startAuthorized() }
                else { DispatchQueue.main.async { self?.permissionDenied = true } }
            }
        default: DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    private func startAuthorized() {
        sessionQueue.async {
            guard self.wantsRunning else { return }
            do {
                if !self.configured { try self.configure(); self.orientConnections() }
                if !self.session.isRunning { self.session.startRunning() }
                self.publishRunning()
            } catch { self.fail(error.localizedDescription) }
        }
    }

    func stop() {
        sessionQueue.async {
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            self.publishRunning()
        }
    }

    private func publishRunning() {
        let running = session.isRunning
        DispatchQueue.main.async { self.isRunning = running; if running { self.permissionDenied = false; self.errorMessage = nil } }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        let newInput = try makeInput(position: position)
        guard session.canAddInput(newInput) else { throw SCOOError.message("이 카메라를 연결할 수 없어요.") }
        session.addInput(newInput); input = newInput
        guard session.canAddOutput(photoOutput), session.canAddOutput(videoOutput) else {
            session.removeInput(newInput); input = nil
            throw SCOOError.message("사진 출력을 준비하지 못했어요.")
        }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .balanced
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        session.addOutput(videoOutput)
        orientConnections()
        configured = true
        let flash = newInput.device.hasFlash
        DispatchQueue.main.async { self.hasFlash = flash }
    }

    private func makeInput(position: AVCaptureDevice.Position) throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw SCOOError.message("카메라가 없는 환경이에요. 시뮬레이터에서는 앨범 사진으로 체험해 주세요.")
        }
        return try AVCaptureDeviceInput(device: device)
    }

    private func orientConnections() {
        // Preview frames stay in the sensor's native orientation; captureOutput rotates/mirrors them
        // per camera, so a swapped input can never leave the feed sideways.
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(0) { connection.videoRotationAngle = 0 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = position == .front
            }
        }
    }

    func flip() {
        sessionQueue.async {
            guard self.configured, self.captureCompletion == nil else { return }
            let next: AVCaptureDevice.Position = self.position == .back ? .front : .back
            do {
                let replacement = try self.makeInput(position: next)
                self.session.beginConfiguration()
                let previous = self.input
                if let previous { self.session.removeInput(previous) }
                if self.session.canAddInput(replacement) {
                    self.session.addInput(replacement); self.input = replacement; self.position = next
                    self.orientConnections()
                    DispatchQueue.main.async { self.zoom = 1; self.hasFlash = replacement.device.hasFlash }
                } else if let previous { self.session.addInput(previous) }
                self.session.commitConfiguration()
                // Connections are rebuilt with the new input; apply again once the change is committed.
                self.orientConnections()
            } catch { self.fail(error.localizedDescription) }
        }
    }

    func setZoom(_ requested: CGFloat) {
        sessionQueue.async {
            guard let device = self.input?.device else { return }
            do {
                try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
                let value = max(device.minAvailableVideoZoomFactor, min(requested, min(3, device.maxAvailableVideoZoomFactor)))
                device.videoZoomFactor = value
                DispatchQueue.main.async { self.zoom = value }
            } catch { self.fail("줌을 바꾸지 못했어요.") }
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async {
            guard let device = self.input?.device else { return }
            do {
                try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = CGPoint(x: point.x, y: self.position == .front ? 1 - point.y : point.y); device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = CGPoint(x: point.x, y: self.position == .front ? 1 - point.y : point.y); device.exposureMode = .continuousAutoExposure
                }
            } catch { self.fail("초점을 맞추지 못했어요.") }
        }
    }

    func capture(flash: Bool, completion: @escaping (Result<Data, Error>) -> Void) {
        sessionQueue.async {
            guard self.session.isRunning, self.captureCompletion == nil else {
                DispatchQueue.main.async { completion(.failure(SCOOError.message("카메라가 준비될 때까지 기다려 주세요."))) }; return
            }
            self.captureCompletion = completion
            DispatchQueue.main.async { self.isCapturing = true }
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            if self.input?.device.hasFlash == true { settings.flashMode = flash ? .on : .off }
            settings.photoQualityPrioritization = .balanced
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func complete(_ result: Result<Data, Error>) {
        let completion = captureCompletion; captureCompletion = nil
        DispatchQueue.main.async { self.isCapturing = false; completion?(result) }
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async { self.errorMessage = message; self.isRunning = self.session.isRunning }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        sessionQueue.async {
            if let error { self.complete(.failure(error)); return }
            guard let data = photo.fileDataRepresentation() else { self.complete(.failure(SCOOError.message("사진 데이터를 받지 못했어요."))); return }
            self.complete(.success(data))
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error { sessionQueue.async { if self.captureCompletion != nil { self.complete(.failure(error)) } } }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var image = CIImage(cvPixelBuffer: buffer)
        // Only orient here when the connection really delivers native landscape frames.
        if connection.videoRotationAngle == 0 && !connection.isVideoMirrored {
            let front = connection.inputPorts.first?.sourceDevicePosition == .front
            image = image.oriented(front ? .leftMirrored : .right)
        }
        lookLock.lock(); let look = selectedLook; lookLock.unlock()
        // Building the CIImage is only a recipe; the GPU does the work when the preview draws.
        preview.show(look.apply(to: image, finishing: false))
    }
}

/// Renders the newest camera frame straight into a Metal view (aspect fill).
final class PreviewRenderer: NSObject, MTKViewDelegate {
    private let device = MTLCreateSystemDefaultDevice()
    private lazy var queue = device?.makeCommandQueue()
    private lazy var context: CIContext? = device.map { CIContext(mtlDevice: $0, options: [.cacheIntermediates: false]) }
    private let lock = NSLock()
    private var pending: CIImage?

    func show(_ image: CIImage) {
        lock.lock(); pending = image; lock.unlock()
    }

    func makeView() -> MTKView {
        let view = MTKView(frame: .zero, device: device)
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.isOpaque = true
        view.clearColor = MTLClearColor(red: 0.08, green: 0.10, blue: 0.09, alpha: 1)
        view.preferredFramesPerSecond = 30
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.autoResizeDrawable = true
        view.contentScaleFactor = min(UIScreen.main.scale, 2)
        view.isUserInteractionEnabled = false
        view.delegate = self
        return view
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    func draw(in view: MTKView) {
        lock.lock(); let image = pending; pending = nil; lock.unlock()
        let size = view.drawableSize
        guard let image, size.width > 0, size.height > 0, image.extent.width > 0, image.extent.height > 0,
              let context, let drawable = view.currentDrawable, let commands = queue?.makeCommandBuffer() else { return }
        let scale = max(size.width / image.extent.width, size.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let filled = scaled.transformed(by: CGAffineTransform(translationX: (size.width - scaled.extent.width) / 2 - scaled.extent.minX,
                                                              y: (size.height - scaled.extent.height) / 2 - scaled.extent.minY))
        let destination = CIRenderDestination(width: Int(size.width), height: Int(size.height), pixelFormat: view.colorPixelFormat,
                                              commandBuffer: commands, mtlTextureProvider: { drawable.texture })
        _ = try? context.startTask(toRender: filled, from: CGRect(origin: .zero, size: size), to: destination, at: .zero)
        commands.present(drawable)
        commands.commit()
    }
}
