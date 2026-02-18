////
////  QuickWorkoutModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import SwiftUI
import UIKit

/// Quick Workout module - quickly start a workout from available exercises
public struct QuickWorkoutModule: AppModule {
    public let id: UUID = ModuleIDs.quickWorkout
    public let displayName: String = "Quick"
    public let iconName: String = "bolt.fill"
    public let description: String = "Start a quick workout from available exercises"

    public var order: Int = 3
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        AnyView(QuickWorkoutModuleView())
    }
}

private struct QuickWorkoutModuleView: View {
    @Environment(ExercisesState.self) var exercisesState
    @Environment(QuickWorkoutState.self) var quickWorkoutState

    @State private var searchText: String = ""
    @State private var startingWorkout: Workout?

    private var filteredExercises: [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = exercisesState.exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var favoriteExercises: [Exercise] {
        exercisesState.exercises
            .filter { quickWorkoutState.isFavorite($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with title
            Text("Quick")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            List {
                // Favorites section
                if !favoriteExercises.isEmpty {
                    Section("Favorites") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(favoriteExercises) { exercise in
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        let workout = Workout(
                                            name: "\(exercise.name) (Quick)",
                                            notes: "",
                                            exercises: [WorkoutExercise(exerciseID: exercise.id)]
                                        )
                                        startingWorkout = workout
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.black)

                                            Text(exercise.name)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.black)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(width: 70, height: 80)
                                        .padding(8)
                                        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                            .padding(.horizontal, 12)
                        }
                        .frame(height: 100)
                        .listRowInsets(EdgeInsets())
                    }
                }

                // Search bar
                Section {
                    SearchField(text: $searchText, placeholder: "Search exercises...")
                }

                // All exercises section
                Section("All Exercises") {
                    ForEach(filteredExercises) { exercise in
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.black)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: quickWorkoutState.isFavorite(exercise.id) ? "star.fill" : "star")
                                .foregroundColor(quickWorkoutState.isFavorite(exercise.id) ? .black : .gray)
                                .contentShape(Rectangle())
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        quickWorkoutState.toggleFavorite(exerciseID: exercise.id)
                                    }
                                )
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            let workout = Workout(
                                name: "\(exercise.name) (Quick)",
                                notes: "",
                                exercises: [WorkoutExercise(exerciseID: exercise.id)]
                            )
                            startingWorkout = workout
                        }
                    }
                }
            }
            .listStyle(.plain)
            .sheet(item: $startingWorkout) { workout in
                StartWorkoutView(workout: workout)
                    .environment(ExercisesState.shared)
                    .environment(MuscleGroupsState.shared)
                    .environment(EquipmentState.shared)
            }
        }
    }
}

#Preview {
    QuickWorkoutModuleView()
        .environment(ExercisesState.shared)
        .environment(QuickWorkoutState.shared)
}
