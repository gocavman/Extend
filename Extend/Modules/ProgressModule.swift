////
////  ProgressModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import UIKit

/// Sample module for tracking workout progress and achievements.
public struct ProgressModule: AppModule {
    public let id: UUID = ModuleIDs.progress
    public let displayName: String = "Log"
    public let iconName: String = "chart.line.uptrend.xyaxis"
    public let description: String = "Track progress and achievements"
    
    public var order: Int = 3
    public var isVisible: Bool = true
    
    public var moduleView: AnyView {
        AnyView(ProgressModuleView())
    }
}

private struct ProgressModuleView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                    
                    Text("Progress")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Monitor your fitness improvements")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 16) {
                    // Stats Cards
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Total Workouts",
                            value: "24",
                            icon: "dumbbell"
                        )
                        
                        StatCard(
                            title: "Streak",
                            value: "7 days",
                            icon: "flame"
                        )
                    }
                    
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Total Minutes",
                            value: "420",
                            icon: "timer"
                        )
                        
                        StatCard(
                            title: "Calories",
                            value: "2,450",
                            icon: "bolt"
                        )
                    }
                    
                    // Recent Activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This Week")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ProgressItemView(day: "Monday", completed: true, sets: 4)
                            ProgressItemView(day: "Tuesday", completed: true, sets: 4)
                            ProgressItemView(day: "Wednesday", completed: false, sets: 0)
                            ProgressItemView(day: "Thursday", completed: true, sets: 5)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.98, green: 0.98, blue: 1.0))
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .cornerRadius(8)
    }
}

// MARK: - Progress Item

private struct ProgressItemView: View {
    let day: String
    let completed: Bool
    let sets: Int
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(completed ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(day)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(completed ? "\(sets) sets completed" : "Not started")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            .cornerRadius(6)
            .foregroundColor(.primary)
        }
    }
}

#Preview {
    ProgressModuleView()
}
