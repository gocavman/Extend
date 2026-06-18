////
////  HealthKitService.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 5/20/26.
////

import Foundation
import HealthKit
import SwiftUI

// MARK: - HKWorkoutActivityType Helper

/// A single entry in the activity type picker.
public struct HKActivityTypeEntry: Identifiable {
    public let label: String
    public let rawValue: UInt
    public var id: UInt { rawValue }
}

/// Provides a sorted list of all meaningful HKWorkoutActivityType values with
/// human-readable display names, plus a converter from raw UInt? back to the enum.
public enum HKWorkoutActivityTypeHelper {
    public static let allCases: [HKActivityTypeEntry] = [
        .init(label: "American Football",          rawValue: HKWorkoutActivityType.americanFootball.rawValue),
        .init(label: "Archery",                    rawValue: HKWorkoutActivityType.archery.rawValue),
        .init(label: "Australian Football",        rawValue: HKWorkoutActivityType.australianFootball.rawValue),
        .init(label: "Badminton",                  rawValue: HKWorkoutActivityType.badminton.rawValue),
        .init(label: "Baseball",                   rawValue: HKWorkoutActivityType.baseball.rawValue),
        .init(label: "Basketball",                 rawValue: HKWorkoutActivityType.basketball.rawValue),
        .init(label: "Bowling",                    rawValue: HKWorkoutActivityType.bowling.rawValue),
        .init(label: "Boxing",                     rawValue: HKWorkoutActivityType.boxing.rawValue),
        .init(label: "Climbing",                   rawValue: HKWorkoutActivityType.climbing.rawValue),
        .init(label: "Cricket",                    rawValue: HKWorkoutActivityType.cricket.rawValue),
        .init(label: "Cross Country Skiing",       rawValue: HKWorkoutActivityType.crossCountrySkiing.rawValue),
        .init(label: "Cross Training",             rawValue: HKWorkoutActivityType.crossTraining.rawValue),
        .init(label: "Curling",                    rawValue: HKWorkoutActivityType.curling.rawValue),
        .init(label: "Cycling",                    rawValue: HKWorkoutActivityType.cycling.rawValue),
        .init(label: "Dance (Cardio)",              rawValue: HKWorkoutActivityType.cardioDance.rawValue),
        .init(label: "Dance (Social)",              rawValue: HKWorkoutActivityType.socialDance.rawValue),
        .init(label: "Disc Sports",                rawValue: HKWorkoutActivityType.discSports.rawValue),
        .init(label: "Downhill Skiing",            rawValue: HKWorkoutActivityType.downhillSkiing.rawValue),
        .init(label: "Elliptical",                 rawValue: HKWorkoutActivityType.elliptical.rawValue),
        .init(label: "Equestrian Sports",          rawValue: HKWorkoutActivityType.equestrianSports.rawValue),
        .init(label: "Fencing",                    rawValue: HKWorkoutActivityType.fencing.rawValue),
        .init(label: "Fishing",                    rawValue: HKWorkoutActivityType.fishing.rawValue),
        .init(label: "Functional Strength Training", rawValue: HKWorkoutActivityType.functionalStrengthTraining.rawValue),
        .init(label: "Golf",                       rawValue: HKWorkoutActivityType.golf.rawValue),
        .init(label: "Gymnastics",                 rawValue: HKWorkoutActivityType.gymnastics.rawValue),
        .init(label: "Handball",                   rawValue: HKWorkoutActivityType.handball.rawValue),
        .init(label: "High Intensity Interval Training", rawValue: HKWorkoutActivityType.highIntensityIntervalTraining.rawValue),
        .init(label: "Hiking",                     rawValue: HKWorkoutActivityType.hiking.rawValue),
        .init(label: "Hockey",                     rawValue: HKWorkoutActivityType.hockey.rawValue),
        .init(label: "Hunting",                    rawValue: HKWorkoutActivityType.hunting.rawValue),
        .init(label: "Jump Rope",                  rawValue: HKWorkoutActivityType.jumpRope.rawValue),
        .init(label: "Kickboxing",                 rawValue: HKWorkoutActivityType.kickboxing.rawValue),
        .init(label: "Lacrosse",                   rawValue: HKWorkoutActivityType.lacrosse.rawValue),
        .init(label: "Martial Arts",               rawValue: HKWorkoutActivityType.martialArts.rawValue),
        .init(label: "Mind and Body",              rawValue: HKWorkoutActivityType.mindAndBody.rawValue),
        .init(label: "Mixed Cardio",               rawValue: HKWorkoutActivityType.mixedCardio.rawValue),
        .init(label: "Other",                      rawValue: HKWorkoutActivityType.other.rawValue),
        .init(label: "Paddle Sports",              rawValue: HKWorkoutActivityType.paddleSports.rawValue),
        .init(label: "Pickleball",                 rawValue: HKWorkoutActivityType.pickleball.rawValue),
        .init(label: "Pilates",                    rawValue: HKWorkoutActivityType.pilates.rawValue),
        .init(label: "Play",                       rawValue: HKWorkoutActivityType.play.rawValue),
        .init(label: "Preparation and Recovery",   rawValue: HKWorkoutActivityType.preparationAndRecovery.rawValue),
        .init(label: "Racquetball",                rawValue: HKWorkoutActivityType.racquetball.rawValue),
        .init(label: "Rowing",                     rawValue: HKWorkoutActivityType.rowing.rawValue),
        .init(label: "Rugby",                      rawValue: HKWorkoutActivityType.rugby.rawValue),
        .init(label: "Running",                    rawValue: HKWorkoutActivityType.running.rawValue),
        .init(label: "Sailing",                    rawValue: HKWorkoutActivityType.sailing.rawValue),
        .init(label: "Skating Sports",             rawValue: HKWorkoutActivityType.skatingSports.rawValue),
        .init(label: "Snowboarding",               rawValue: HKWorkoutActivityType.snowboarding.rawValue),
        .init(label: "Snow Sports",                rawValue: HKWorkoutActivityType.snowSports.rawValue),
        .init(label: "Soccer",                     rawValue: HKWorkoutActivityType.soccer.rawValue),
        .init(label: "Softball",                   rawValue: HKWorkoutActivityType.softball.rawValue),
        .init(label: "Squash",                     rawValue: HKWorkoutActivityType.squash.rawValue),
        .init(label: "Stair Climbing",             rawValue: HKWorkoutActivityType.stairClimbing.rawValue),
        .init(label: "Stairs",                     rawValue: HKWorkoutActivityType.stairs.rawValue),
        .init(label: "Step Training",              rawValue: HKWorkoutActivityType.stepTraining.rawValue),
        .init(label: "Strength Training (Traditional)", rawValue: HKWorkoutActivityType.traditionalStrengthTraining.rawValue),
        .init(label: "Surfing Sports",             rawValue: HKWorkoutActivityType.surfingSports.rawValue),
        .init(label: "Swimming",                   rawValue: HKWorkoutActivityType.swimming.rawValue),
        .init(label: "Table Tennis",               rawValue: HKWorkoutActivityType.tableTennis.rawValue),
        .init(label: "Tennis",                     rawValue: HKWorkoutActivityType.tennis.rawValue),
        .init(label: "Track and Field",            rawValue: HKWorkoutActivityType.trackAndField.rawValue),
        .init(label: "Volleyball",                 rawValue: HKWorkoutActivityType.volleyball.rawValue),
        .init(label: "Walking",                    rawValue: HKWorkoutActivityType.walking.rawValue),
        .init(label: "Water Fitness",              rawValue: HKWorkoutActivityType.waterFitness.rawValue),
        .init(label: "Water Polo",                 rawValue: HKWorkoutActivityType.waterPolo.rawValue),
        .init(label: "Water Sports",               rawValue: HKWorkoutActivityType.waterSports.rawValue),
        .init(label: "Wrestling",                  rawValue: HKWorkoutActivityType.wrestling.rawValue),
        .init(label: "Yoga",                       rawValue: HKWorkoutActivityType.yoga.rawValue),
    ].sorted { $0.label < $1.label }

    /// Convert a stored raw UInt? back to an HKWorkoutActivityType. nil → .other.
    public static func hkType(from rawValue: UInt?) -> HKWorkoutActivityType {
        guard let raw = rawValue,
              let type = HKWorkoutActivityType(rawValue: raw) else {
            return .other
        }
        return type
    }

    /// Human-readable label for a given raw value, or nil if not found.
    public static func label(for rawValue: UInt?) -> String? {
        guard let raw = rawValue else { return nil }
        return allCases.first(where: { $0.rawValue == raw })?.label
    }
}

// MARK: - HKActivityTypePicker

/// A reusable picker for HKWorkoutActivityType, binding to a UInt? raw value.
/// Shows only when HealthKit export is enabled.
struct HKActivityTypePicker: View {
    @Binding var rawValue: UInt?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $rawValue) {
                Text("Default (Other)").tag(UInt?.none)
                ForEach(HKWorkoutActivityTypeHelper.allCases) { entry in
                    Text(entry.label).tag(UInt?.some(entry.rawValue))
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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

    /// Saves a completed workout to Apple Health.
    /// Returns the UUID of the created HKWorkout, or nil on failure.
    @discardableResult
    public func exportStrengthWorkout(
        startDate: Date,
        endDate: Date,
        totalEnergyBurned: Double? = nil,
        activityType: HKWorkoutActivityType = .other
    ) async throws -> UUID? {
        guard isAvailable else { return nil }

        let builder = HKWorkoutBuilder(healthStore: store, configuration: workoutConfiguration(activityType: activityType), device: .local())

        try await builder.beginCollection(at: startDate)

        if let calories = totalEnergyBurned, calories > 0 {
            let energyType = HKQuantityType(.activeEnergyBurned)
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            let sample = HKQuantitySample(type: energyType, quantity: quantity, start: startDate, end: endDate)
            try await builder.addSamples([sample])
        }

        try await builder.endCollection(at: endDate)
        let workout = try await builder.finishWorkout()
        return workout?.uuid
    }

    private func workoutConfiguration(activityType: HKWorkoutActivityType = .other) -> HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        return config
    }

    // MARK: - Estimating calories

    /// Very rough estimate: 5 kcal per minute for strength training.
    public func estimatedCalories(durationSeconds: TimeInterval) -> Double {
        (durationSeconds / 60.0) * 5.0
    }

    // MARK: - Import: Workouts

    /// Fetch workouts from Apple Health since a given date,
    /// filtered to the user's enabled activity types.
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
        // Reuse the picker's label table so every supported HK activity type
        // (Swimming, Mind and Body, Golf, …) imports under its proper name
        // instead of falling through to a generic "Cardio Workout".
        if let label = HKWorkoutActivityTypeHelper.label(for: activityType.rawValue) {
            return label
        }
        return "Workout"
    }

    // MARK: - Activity type helpers

    public func enabledActivityTypes(state: HealthKitState) -> Set<HKWorkoutActivityType> {
        Set(state.importActivityTypes.compactMap { HKWorkoutActivityType(rawValue: $0) })
    }
}
