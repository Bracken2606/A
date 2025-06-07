//
//  LinearVisualiserConductor.swift
//  MicVisualiser
//
//  Created by Felix Bourne on 6/7/25.
//

import AudioKit
import AudioKitUI
import AVFoundation

class LinearVisualizerConductor: ObservableObject, HasAudioEngine {
    let engine = AudioEngine()
    let mic: AudioEngine.InputNode
    let mixer: Mixer

    init() {
        guard let input = engine.input else {
            fatalError("No input device available")
        }
        mic = input
        mixer = Mixer(mic)
        engine.output = mixer
    }
}
