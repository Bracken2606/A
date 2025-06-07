import AudioKit
import AVFoundation

class LinearVisualizerConductor: ObservableObject, HasAudioEngine {
    let engine = AudioEngine()
    let mic: AudioEngine.InputNode
    let mixer: Mixer

    let vbanStreamer: VBANStreamer

    init(vbanStreamer: VBANStreamer) {
        guard let input = engine.input else {
            fatalError("No input device available")
        }
        self.mic = input
        self.mixer = Mixer(mic)
        engine.output = mixer

        self.vbanStreamer = vbanStreamer

        // Install tap for VBAN streaming only
        mic.avAudioNode.installTap(
            onBus: 0,
            bufferSize: 256,
            format: mixer.avAudioNode.inputFormat(forBus: 0)
        ) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.vbanStreamer.fillPayloadAndSend(audioBuffer: buffer)
        }
    }

    func start() {
        do {
            try engine.start()
        } catch {
            print("AudioKit engine start error: \(error)")
        }
    }

    func stop() {
        mic.avAudioNode.removeTap(onBus: 0)
        engine.stop()
    }
}
