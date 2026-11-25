import AVFoundation
import SwiftUI

/// Back camera -> one continuous video file. Every frame also goes to onFrame (tracking will use it).
final class CameraRecorder: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published private(set) var isRecording = false
    @Published var error: String?

    /// Called for every camera frame, on a background queue.
    var onFrame: ((CMSampleBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let frameQueue = DispatchQueue(label: "camera.frames")
    private let output = AVCaptureVideoDataOutput()
    private var configured = false

    // Only touched on frameQueue
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var started = false

    private let lock = NSLock()
    private var startTime: Double?

    func configure() async {
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
        default: allowed = false
        }
        guard allowed else {
            await MainActor.run { self.error = "Camera access is off. Turn it on in Settings > SmartSkate." }
            return
        }
        sessionQueue.async { self.setUpSession() }
    }

    private func setUpSession() {
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = session.canSetSessionPreset(.hd4K3840x2160) ? .hd4K3840x2160 : .high
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            output.alwaysDiscardsLateVideoFrames = false
            output.setSampleBufferDelegate(self, queue: frameQueue)
            if session.canAddOutput(output) { session.addOutput(output) }
            if let c = output.connection(with: .video), c.isVideoRotationAngleSupported(0) {
                c.videoRotationAngle = 0
            }
            session.commitConfiguration()
            configured = true
        }
        if !session.isRunning { session.startRunning() }
    }

    func shutdown() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// Seconds since the first recorded frame, or nil before recording starts.
    func currentVideoTime() -> Double? {
        lock.lock(); defer { lock.unlock() }
        guard let startTime else { return nil }
        let clock = session.synchronizationClock ?? CMClockGetHostTimeClock()
        return CMClockGetTime(clock).seconds - startTime
    }

    func startRecording(to url: URL) {
        frameQueue.async {
            do {
                let w = try AVAssetWriter(outputURL: url, fileType: .mov)
                let settings = self.output.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                input.expectsMediaDataInRealTime = true
                guard w.canAdd(input) else {
                    throw NSError(domain: "SmartSkate", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Couldn't set up the video file."])
                }
                w.add(input)
                self.writer = w
                self.writerInput = input
                self.started = false
                self.lock.lock(); self.startTime = nil; self.lock.unlock()
                DispatchQueue.main.async { self.isRecording = true }
            } catch {
                DispatchQueue.main.async { self.error = error.localizedDescription }
            }
        }
    }

    /// Finishes the file. Returns the video length in seconds.
    func stopRecording() async -> Double {
        let duration = currentVideoTime() ?? 0
        return await withCheckedContinuation { cont in
            frameQueue.async {
                guard let writer = self.writer, let input = self.writerInput else {
                    cont.resume(returning: 0); return
                }
                self.writer = nil
                self.writerInput = nil
                DispatchQueue.main.async { self.isRecording = false }
                guard self.started, writer.status == .writing else {
                    writer.cancelWriting()
                    cont.resume(returning: 0); return
                }
                input.markAsFinished()
                writer.finishWriting { cont.resume(returning: duration) }
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let writer, let writerInput {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if !started, writer.startWriting() {
                writer.startSession(atSourceTime: pts)
                started = true
                lock.lock(); startTime = pts.seconds; lock.unlock()
            }
            if started, writer.status == .writing, writerInput.isReadyForMoreMediaData {
                writerInput.append(sampleBuffer)
            }
        }
        onFrame?(sampleBuffer)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if let c = view.previewLayer.connection, c.isVideoRotationAngleSupported(0) {
            c.videoRotationAngle = 0
        }
    }
}
