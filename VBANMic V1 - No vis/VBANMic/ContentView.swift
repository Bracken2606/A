import SwiftUI

struct ContentView: View {
    @StateObject private var audioCaptureManager = AudioCaptureManager()
    private let vbanStreamer = VBANStreamer(
        channels: 1,
        sampleRate: 48000,
        bitFormat: VBAN_BITFMT_16_INT,
        payloadSamples: 256
    )
    
    @State private var isStreaming = false
    @State private var isMicAvailable = true

    var body: some View {
        VStack(spacing: 40) {
            Text(isStreaming ? "Streaming Microphone..." : "Microphone Off")
                .font(.title)
                .padding(.top, 60)
            
            Button(action: {
                if isStreaming {
                    stopStreaming()
                } else {
                    startStreaming()
                }
            }) {
                Image(systemName: isStreaming ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(isMicAvailable ? .red : .gray)
                    .padding()
                    .background(Circle().fill(Color.black.opacity(0.1)))
            }
            .disabled(!isMicAvailable)
        }
        .onAppear {
            audioCaptureManager.onAudioBuffer = { buffer in
                vbanStreamer.fillPayloadAndSend(audioBuffer: buffer)
            }
            audioCaptureManager.onMicAvailabilityChanged = { available in
                DispatchQueue.main.async {
                    self.isMicAvailable = available
                }
            }
            audioCaptureManager.checkAndRequestPermission { granted in
                DispatchQueue.main.async {
                    self.isMicAvailable = granted
                }
            }
        }
        .padding()
    }
    
    func startStreaming() {
        do {
            vbanStreamer.setupConnection(to: "192.168.1.35", port: 6980) // Replace with your target IP/port
            try audioCaptureManager.startCapturing()
            isStreaming = true
        } catch {
            print("Failed to start streaming: \(error)")
            isStreaming = false
        }
    }
    
    func stopStreaming() {
        audioCaptureManager.stopCapturing()
        vbanStreamer.stop()
        isStreaming = false
    }
}
