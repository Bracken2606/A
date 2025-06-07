import Foundation
import Network
import AVFoundation

extension VBANStreamer {
    func sendTestUDP(volume: Float = 0.5) {
        guard let conn = connection else {
            print("Connection not setup")
            return
        }
        
        let message = "Test UDP Packet - Volume: \(volume)"
        guard let data = message.data(using: .utf8) else { return }
        
        conn.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Test UDP send error: \(error)")
            } else {
                print("Test UDP sent: \(message)")
            }
        })
    }
}

class VBANStreamer {
    private let headerSize = MemoryLayout<VBanHeader>.size
    private let payloadSamples: Int
    private let channels: Int32
    private let bitFormat: VBanBitResolution
    private let bytesPerSample: Int
    private let packetSize: Int
    private let buffer: UnsafeMutableRawPointer
    private var connection: NWConnection?
    
    init(channels: Int32 = 1,
         sampleRate: Int32 = 48000,
         bitFormat: VBanBitResolution = VBAN_BITFMT_16_INT,
         payloadSamples: Int = 256) // Match your capture buffer size here
    {
        self.payloadSamples = payloadSamples
        self.channels = channels
        self.bitFormat = bitFormat
        self.bytesPerSample = MemoryLayout<Int16>.size
        
        print("VBAN Header size from Swift MemoryLayout: \(MemoryLayout<VBanHeader>.size)")
        print("Expected VBAN_HEADER_SIZE from C: 28")
        print("Payload samples set to \(payloadSamples), channels: \(channels)")
        
        self.packetSize = MemoryLayout<VBanHeader>.size + payloadSamples * Int(channels) * bytesPerSample
        buffer = UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: MemoryLayout<Int16>.alignment)
        buffer.initializeMemory(as: UInt8.self, repeating: 0, count: packetSize)
        
        var config = stream_config_t(
            nb_channels: UInt32(channels),
            sample_rate: UInt32(sampleRate),
            bit_fmt: bitFormat
        )
        
        _ = packet_init_header(buffer.assumingMemoryBound(to: CChar.self),
                               &config,
                               "BRCKMIC")
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func setupConnection(to ip: String, port: UInt16) {
        let host = NWEndpoint.Host(ip)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: host, port: nwPort, using: .udp)
        
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connection ready")
            case .failed(let error):
                print("Connection failed: \(error)")
            default:
                break
            }
        }
        
        connection?.start(queue: .global())
    }
    
    func fillPayloadAndSend(audioBuffer: AVAudioPCMBuffer) {
        guard let floatData = audioBuffer.floatChannelData else { return }
        let totalFrames = Int(audioBuffer.frameLength)
        let channels = Int(audioBuffer.format.channelCount)
        
        // Debug print: frame length per call
        print("fillPayloadAndSend called with frameLength:", totalFrames)
        
        var frameIndex = 0
        while frameIndex < totalFrames {
            let framesLeft = totalFrames - frameIndex
            let framesThisChunk = min(framesLeft, payloadSamples)
            
            let audioByteCount = framesThisChunk * channels * bytesPerSample
            
            // Clear payload area
            let payloadPtr = buffer.advanced(by: headerSize)
            let int16Ptr = payloadPtr.bindMemory(to: Int16.self, capacity: framesThisChunk * channels)
            
            // Convert float samples to Int16
            for frame in 0..<framesThisChunk {
                for channel in 0..<channels {
                    let floatSample = floatData[channel][frameIndex + frame]
                    let clamped = max(-1.0, min(1.0, floatSample))
                    int16Ptr[frame * channels + channel] = Int16(clamped * Float(Int16.max))
                }
            }
            
            _ = packet_set_new_content(buffer.assumingMemoryBound(to: CChar.self), audioByteCount)
            
            if let conn = connection {
                let packetData = Data(bytes: buffer, count: headerSize + audioByteCount)
                conn.send(content: packetData, completion: .contentProcessed { error in
                    if let error = error {
                        print("VBAN send error: \(error)")
                    }
                })
            }
            
            frameIndex += framesThisChunk
        }
    }
    
    func stop() {
        connection?.cancel()
        connection = nil
    }
}
