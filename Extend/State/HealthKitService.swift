////
////  HealthKitService.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 5/20/26.
////

import Foundation
import HealthKit

/// Wraps HKHealthStore operations for exporting strength workouts and
/// importing cardio workouts from Apple Health.
public final class HealthKitService {
    public static let shared = HealthKitService()

    private let store = HKHealthStore()

    // MARK: - Types to read/write

    private var typesToShare: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    private var typesToRead: Set<HKObjectType> {
        [HKObjectType.workoutType()]
    }

    // MARK: - Authorization

    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request HealthKit authorization. Calls the completion block on the main actor.
    public func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    // MARK: - Export: Strength Workout

    /// Saves a completed strength workout to Apple Health.
    /// Returns the UUID of the created HKWorkout, or nil on failure.
    @discardableResult
    public func exportStrengthWorkout(
        startDate: Date,
        endDate: Date,
        totalEnergyBurned: Double? = nil
    ) async throws -> UUID? {
        guard isAvailable else { return nil }

        let builder = HKWorkoutBuilder(healthStore: store, configuration: workoutConfiguration(), device: .local())

        try await builder.beginCollection(at: startDate)

        if let calories = totalEnergyBurned, calories > 0 {
            let energyType = HKQuantityType(.activeEnergyBurned)
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            let sample = HKQuantitySample(type: energyType, quantity: quantity, start: startDate, end: endDate)
            try await builder.addSamples([sample])
        }

        try await builder.endCollection(at: endDate)
        let workout = try await builder.finishWorkout()
        return workout.uuid
    }

    private func workoutConfiguration() -> HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        return config
    }

    // MARK: - Estimating calories

    /// Very rough estimate: 5 kcal per minute for strength training.
    public func estimatedCalories(durationSeconds: TimeInterval) -> Double {
        (durationSeconds / 60.0) * 5.0
    }

    // MARK: - Import: Cardio Workouts

    /// Fetch cardio workouts from Apple Health since a given date.
    /// Returns workouts matching any of the enabled activity types.
    public func fetchCardioWorkouts(
        since startDate: Date,
        activityTypes: Set<HKWorkoutActivityType>
    ) async throws -> [HKWorkout] {
        guard isAvailable else { return [] }
        guard !activityTypes.isEmpty else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout] ?? [])
                    .filter { activityTypes.contains($0.workoutActivityType) }
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    // MARK: - Convert HKWorkout to WorkoutLog

    public func workoutLog(from hkWorkout: HKWorkout) -> WorkoutLog {
        let activityName = displayName(for: hkWorkout.workoutActivityType)
        return WorkoutLog(
            workoutName: activityName,
            completedAt: hkWorkout.endDate,
            exercises: [],
            notes: "Imported from Apple Health",
            duration: hkWorkout.duration,
            healthKitUUID: hkWorkout.uuid
        )
    }

    private func displayName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:               return "Running"
        case .cycling:               return "Cycling"
        case .rowing:                return "Rowing"
        case .walking:               return "Walking"
        case .hiking:                return "Hiking"
        default:                     return "Cardio Workout"
        }
    }

    // MARK: - Activity type helpers

    public func enabledActivityTypes(state: HealthKitState) -> Set<HKWorkoutActivityType> {
        var types = Set<HKWorkoutActivityType>()
        if state.importRunning  { types.insert(.running) }
        if state.importCycling  { types.insert(.cycling) }
        if state.importRowing   { types.insert(.rowing) }
        if state.importWalking  { types.insert(.walking); types.insert(.hiking) }
        return types
    }
}
