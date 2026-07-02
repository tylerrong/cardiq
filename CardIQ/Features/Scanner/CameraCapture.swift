import SwiftUI
#if canImport(UIKit)
import AVFoundation
import Combine
import CoreImage
import UIKit
import Vision

/// Live detection state for the scan box — drives the frame color and guidance.
enum CardDetection: Equatable {
    case searching   // no card in frame
    case adjusting   // card seen but too small / off
    case ready       // well-framed — good to capture
}

/// Drives the live camera preview, real-time card detection, and a single
/// perspective-corrected capture cropped to the detected card.
final class CardCameraController: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.cardiq.camera")
    private let ciContext = CIContext()

    @Published var detection: CardDetection = .searching
    @Published var authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @Published var torchOn = false
    /// No usable camera: simulator, permission denied, or hardware in use.
    /// The scan UI shows an "import instead" state and the shutter no-ops.
    @Published var cameraUnavailable = false

    /// Set by the view; called (on main) with the cropped card image when captured.
    var onCapture: ((Data) -> Void)?
    /// Called (on main) when a capture attempt can't produce a photo, so the
    /// view can unwind capture-in-progress UI (e.g. the flash overlay).
    var onCaptureFailed: (() -> Void)?
    private var configured = false
    private var captureDevice: AVCaptureDevice?

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            DispatchQueue.main.async { self.authorized = granted }
            guard granted else {
                DispatchQueue.main.async { self.cameraUnavailable = true }
                return
            }
            self.queue.async {
                self.configureIfNeeded()
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.setTorch(on: false)
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    /// Toggle the continuous torch for low-light framing.
    func toggleTorch() {
        queue.async { [weak self] in
            guard let self else { return }
            self.setTorch(on: !self.torchOn)
        }
    }

    /// Must be called on `queue`. Updates the device torch and publishes state.
    private func setTorch(on: Bool) {
        guard let device = captureDevice, device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        DispatchQueue.main.async { [weak self] in
            if self?.torchOn != on { self?.torchOn = on }
        }
    }

    /// Manual shutter — capture and crop to the detected card.
    func capture() {
        queue.async { [weak self] in
            guard let self else { return }
            // capturePhoto throws an unrecoverable ObjC exception when the
            // session has no live video connection (simulator, permission
            // denied, session interrupted) — bail out instead of crashing.
            guard self.configured,
                  let connection = self.photoOutput.connection(with: .video),
                  connection.isEnabled, connection.isActive else {
                DispatchQueue.main.async { [weak self] in
                    self?.cameraUnavailable = true
                    self?.onCaptureFailed?()
                }
                return
            }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = Self.bestCaptureDevice(),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            captureDevice = device
            configureFocus(device)
        } else {
            DispatchQueue.main.async { [weak self] in self?.cameraUnavailable = true }
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()
        configured = true
    }

    /// Prefer a virtual multi-lens device: it auto-switches to the ultra-wide
    /// macro lens when the subject gets close — exactly the "fill the frame
    /// with the card" case where the bare wide lens can't focus.
    private static func bestCaptureDevice() -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices.first
    }

    /// Card scanning is always close-up: restrict autofocus to the near range
    /// so the lens doesn't hunt to infinity, and disable smooth (video) AF so
    /// it snaps instead of glides.
    private func configureFocus(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = false
        }
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        device.unlockForConfiguration()
    }

    /// Tap-to-focus: refocus and re-expose at a point of interest
    /// (device-space coordinates, 0-1).
    func focus(at devicePoint: CGPoint) {
        queue.async { [weak self] in
            guard let self, let device = self.captureDevice,
                  (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }
    }

    private func detectRectangles(handler: VNImageRequestHandler) -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5     // ~card 2.5:3.5 = 0.71 (portrait); device-tune
        request.maximumAspectRatio = 0.85
        request.minimumSize = 0.3
        request.minimumConfidence = 0.7
        request.maximumObservations = 1
        try? handler.perform([request])
        return request.results?.first
    }
}

// MARK: - Live detection (feedback)
extension CardCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        let state: CardDetection
        if let rect = detectRectangles(handler: handler) {
            let area = rect.boundingBox.width * rect.boundingBox.height
            state = area >= 0.22 ? .ready : .adjusting
        } else {
            state = .searching
        }
        DispatchQueue.main.async { [weak self] in
            if self?.detection != state { self?.detection = state }
        }
    }
}

// MARK: - Capture + crop
extension CardCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            let failure = onCaptureFailed
            DispatchQueue.main.async { failure?() }
            return
        }
        let result = croppedToCard(data) ?? data
        let completion = onCapture
        DispatchQueue.main.async { completion?(result) }
    }

    /// Re-detects the card on the captured photo (orientation-correct) and
    /// perspective-corrects + crops to it. Falls back to the full frame on miss.
    private func croppedToCard(_ data: Data) -> Data? {
        guard let raw = CIImage(data: data) else { return nil }
        let orientation = (raw.properties[kCGImagePropertyOrientation as String] as? UInt32)
            .flatMap { CGImagePropertyOrientation(rawValue: $0) } ?? .up
        let image = raw.oriented(orientation)

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        guard let rect = detectRectangles(handler: handler) else { return nil }

        let w = image.extent.width, h = image.extent.height
        func scaled(_ p: CGPoint) -> CIVector { CIVector(x: p.x * w, y: p.y * h) }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(scaled(rect.topLeft), forKey: "inputTopLeft")
        filter.setValue(scaled(rect.topRight), forKey: "inputTopRight")
        filter.setValue(scaled(rect.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(scaled(rect.bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.9)
    }
}

/// SwiftUI view that renders the live camera preview layer. Tapping the
/// preview refocuses at that point.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Called with the tapped point in device space (0-1) for tap-to-focus.
    var onTap: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.onTap = onTap
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var onTap: ((CGPoint) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            let layerPoint = gesture.location(in: self)
            let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            onTap?(devicePoint)
        }
    }
}
#endif
