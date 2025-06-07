//
//  LinearVisualiserView.swift
//  MicVisualiser
//
//  Created by Felix Bourne on 6/7/25.
//

import SwiftUI

struct LinearVisualizerView: View {
    @StateObject var conductor = LinearVisualizerConductor()
    @State private var hueVal = 0
    @Environment(\.scenePhase) private var scenePhase

    func hueValIncrease() {
        hueVal += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hueValIncrease()
        }
    }

    var body: some View {
        VStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                FFTView2(conductor.mixer,
                         barColor: .blue,
                         placeMiddle: true,
                         barCount: 40)
            }
        }
        .hueRotation(.degrees(Double(hueVal)))
        .onAppear {
            conductor.start()
            hueValIncrease()
        }
        .onDisappear {
            conductor.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            conductor.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            conductor.stop()
        }
    }
}

