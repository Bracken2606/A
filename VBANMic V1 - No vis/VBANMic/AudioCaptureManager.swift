import AVFoundation
import Combine

class AudioCaptureManager: ObservableObject {
    // AVAudioEngine for raw mic input
    let avEngine = AVAudioEngine()
    var inputNode: AVAudioInputNode? { avEngine.inputNode }

    var onVolumeUpdate: ((Float) -> Void)?
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    private let chunkSize: AVAudioFrameCount = 256
    var onMicAvailabilityChanged: ((Bool) -> Void)?

    private var isMicAvailable: Bool = true {
        didSet {
            if oldValue != isMicAvailable {
                DispatchQueue.main.async {
                    self.onMicAvailabilityChanged?(self.isMicAvailable)
                }
            }
        }
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        updateMicAvailability()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func updateMicAvailability() {
        let session = AVAudioSession.sharedInstance()
        isMicAvailable = session.recordPermission == .granted && session.isInputAvailable
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            isMicAvailable = false
        case .ended:
            updateMicAvailability()
        @unknown default:
            break
        }
    }

    func isRecordingPermissionGranted() -> Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func requestRecordingPermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func checkAndRequestPermission(completion: @escaping (Bool) -> Void) {
        if isRecordingPermissionGranted() {
            completion(true)
        } else {
            requestRecordingPermission(completion: completion)
        }
    }

    func startCapturing() throws {
        updateMicAvailability()
        guard isMicAvailable else {
            throw NSError(domain: "AudioCaptureManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone is unavailable"])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setPreferredSampleRate(48000)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        print("IOBufferDuration:", session.ioBufferDuration)

        guard let inputNode = inputNode else {
            throw NSError(domain: "AudioCaptureManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No AVAudio input node"])
        }

        let inputFormat = inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: chunkSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            if let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += channelData[i] * channelData[i]
                }
                let rms = sqrt(sum / Float(frameLength))

                DispatchQueue.main.async {
                    self.onVolumeUpdate?(rms)
                }
            }

            self.processBuffer(buffer)
        }

        avEngine.prepare()
        try avEngine.start()
    }

    func stopCapturing() {
        inputNode?.removeTap(onBus: 0)
        avEngine.stop()
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let onAudioBuffer = onAudioBuffer else { return }

        let totalFrames = Int(buffer.frameLength)
        let format = buffer.format
        let channels = Int(format.channelCount)
        let chunkFrames = Int(chunkSize)

        guard let floatData = buffer.floatChannelData else {
            onAudioBuffer(buffer)
            return
        }

        var offset = 0
        while offset < totalFrames {
            let framesLeft = totalFrames - offset
            let framesThisChunk = min(chunkFrames, framesLeft)

            guard let chunkBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(framesThisChunk)) else {
                break
            }

            chunkBuffer.frameLength = AVAudioFrameCount(framesThisChunk)

            for channel in 0..<channels {
                let src = floatData[channel] + offset
                let dst = chunkBuffer.floatChannelData![channel]
                dst.update(from: src, count: framesThisChunk)
            }

            onAudioBuffer(chunkBuffer)

            offset += framesThisChunk
        }
    }
}
