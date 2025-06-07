//
//  AudioLevelViewModel.swift
//  VBANMic
//
//  Created by Felix Bourne on 6/6/25.
//

import Foundation
import Combine

class AudioLevelViewModel: ObservableObject {
    @Published var currentLevel: Float = 0.0
}
