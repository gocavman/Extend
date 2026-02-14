////
////  TimerModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import Combine
import UIKit

/// Sample module for rest timers and interval training.
public struct TimerModule: AppModule {
    public let id: UUID = ModuleIDs.timer
    public let displayName: String = "Timer"
    public let iconName: String = "timer"
    public let description: String = "Rest timers and interval training"
    
    public var order: Int = 5
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(TimerModuleView())
    }
}

private struct TimerModuleView: View {
    @State private var remainingSeconds: Int = 300
    @State private var isRunning: Bool = false
    @State private var selectedDuration: Int = 5
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
                
                Text("Rest Timer")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Track rest periods between sets")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 24) {
                // Timer Display
                VStack(spacing: 8) {
                    Text(timeString(remainingSeconds))
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    
                    Text("minutes : seconds")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(40)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .cornerRadius(12)
                
                // Controls
                HStack(spacing: 16) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        toggleTimer()
                    }) {
                        Text(isRunning ? "Pause" : "Start")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        resetTimer()
                    }) {
                        Text("Reset")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                }
                
                // Duration Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        ForEach([1, 3, 5, 10], id: \.self) { minutes in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                setDuration(minutes)
                            }) {
                                Text("\(minutes)m")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(selectedDuration == minutes ? Color.orange : Color(red: 0.96, green: 0.96, blue: 0.97))
                                    .foregroundColor(selectedDuration == minutes ? .white : .black)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.98, green: 0.98, blue: 1.0))
        .onReceive(timer) { _ in
            if isRunning && remainingSeconds > 0 {
                remainingSeconds -= 1
            }
        }
    }
    
    private func toggleTimer() {
        isRunning.toggle()
    }
    
    private func resetTimer() {
        isRunning = false
        remainingSeconds = selectedDuration * 60
    }
    
    private func setDuration(_ minutes: Int) {
        selectedDuration = minutes
        remainingSeconds = minutes * 60
        isRunning = false
    }
    
    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

#Preview {
    TimerModuleView()
}
