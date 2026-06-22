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

    /// Active observer query for new HKWorkouts. Held to keep the subscription alive.
    private var workoutObserverQuery: HKObserverQuery?

    // MARK: - Types to read/write

    private var typesToShare: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned)
        ]
    }

    private var typesToRead: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime)
        ]
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

    // MARK: - Live Workout Observation

    /// Starts an HKObserverQuery that fires whenever a new workout is added to Apple Health,
    /// plus enables background delivery so the callback fires even when the app is
    /// backgrounded. Safe to call multiple times — the query is registered only once.
    public func startObservingNewWorkouts(onChange: @escaping @Sendable () -> Void) {
        guard isAvailable else { return }
        guard workoutObserverQuery == nil else { return }

        let workoutType = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completionHandler, error in
            if error == nil {
                onChange()
            }
            completionHandler()
        }
        store.execute(query)
        workoutObserverQuery = query

        store.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in
            // Best-effort: silent if the user denied background delivery permission.
        }
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
            // If the user hasn't granted active-energy share permission, the sample add
            // can throw — but we still want the workout itself to save so it contributes
            // to Exercise Minutes. Energy is best-effort.
            try? await builder.addSamples([sample])
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

    /// Rough kcal/min for an "average" ~70 kg adult, derived from MET values
    /// (Compendium of Physical Activities). These are intentionally conservative —
    /// Apple Health will still infer Exercise Minutes from workout duration even
    /// if the energy estimate is low.
    public func kcalPerMinute(for activityType: HKWorkoutActivityType) -> Double {
        switch activityType {
        // Low intensity / mind-body (~3 MET)
        case .yoga, .pilates, .mindAndBody, .flexibility, .preparationAndRecovery, .cooldown, .taiChi:
            return 3.0
        // Walking (~4 MET)
        case .walking, .wheelchairWalkPace:
            return 4.0
        // Strength training (~5 MET)
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining, .barre:
            return 5.0
        // Light-recreation sports (~5 MET)
        case .dance, .socialDance, .fencing, .archery, .bowling, .equestrianSports, .fishing, .golf, .hunting:
            return 5.0
        // Team-recreation sports (~6 MET)
        case .tableTennis, .badminton, .volleyball, .softball, .baseball, .cricket,
             .americanFootball, .australianFootball, .rugby:
            return 6.0
        // Cross / cardio machines + outdoor activity (~7 MET)
        case .crossTraining, .mixedCardio, .stairs, .stepTraining, .elliptical,
             .hiking, .surfingSports, .waterSports, .waterFitness, .waterPolo,
             .snowSports, .crossCountrySkiing, .downhillSkiing, .snowboarding, .skatingSports:
            return 7.0
        // Racquet sports (~7.5 MET)
        case .tennis, .squash, .racquetball, .pickleball, .handball, .lacrosse, .hockey, .paddleSports:
            return 7.5
        // Field / mixed-intensity sports (~8 MET)
        case .basketball, .soccer, .martialArts, .discSports, .trackAndField:
            return 8.0
        // Cycling, rowing (~8.5 MET)
        case .cycling, .handCycling, .wheelchairRunPace, .rowing:
            return 8.5
        // Swimming (~9 MET)
        case .swimming:
            return 9.0
        // High-intensity (~10 MET)
        case .running, .kickboxing, .boxing, .wrestling, .stairClimbing, .climbing:
            return 10.0
        // Maximal-intensity (~11 MET)
        case .highIntensityIntervalTraining, .jumpRope:
            return 11.0
        // Generic / other, plus any case we haven't categorized → conservative
        default:
            return 4.0
        }
    }

    /// Estimate calories burned for a session of `durationSeconds` doing `activityType`.
    /// `bodyWeightKg` scales the result against the 70 kg baseline used by `kcalPerMinute`.
    /// If `bodyWeightKg` is nil or non-positive, the unscaled baseline estimate is returned.
    public func estimatedCalories(
        durationSeconds: TimeInterval,
        activityType: HKWorkoutActivityType = .other,
        bodyWeightKg: Double? = nil
    ) -> Double {
        let base = (durationSeconds / 60.0) * kcalPerMinute(for: activityType)
        if let weight = bodyWeightKg, weight > 0 {
            return base * (weight / 70.0)
        }
        return base
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

    /// Builds a `WorkoutLog` with a single `LoggedExercise` tied to `exercise`,
    /// carrying the workout's duration (in `activeSeconds`) and total distance
    /// (in meters, when Apple Health provides it). Cardio entries imported this
    /// way show up in the Exercise/Muscle/Equipment history and graphs once the
    /// exercise has the appropriate links assigned.
    public func workoutLog(from hkWorkout: HKWorkout, exercise: Exercise) -> WorkoutLog {
        let isIndoor = hkWorkout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
        // Map Apple Health's indoor/outdoor flag to the matching equipment
        // — Treadmill when indoor, None when outdoor — so imported runs and
        // walks pick up the right equipment instead of the exercise's
        // default. Falls back to the default when the metadata is absent
        // or when the exercise doesn't list the preferred equipment.
        let treadmillID = UUID(uuidString: "0000010A-0000-0000-0000-000000000000")!
        let noneID = UUID(uuidString: "00000100-0000-0000-0000-000000000000")!
        let resolvedEquipment: [UUID] = {
            guard let isIndoor else { return exercise.defaultEquipmentIDs }
            let preferred = isIndoor ? treadmillID : noneID
            if exercise.equipmentIDs.contains(preferred) { return [preferred] }
            return exercise.defaultEquipmentIDs
        }()

        let logged = LoggedExercise(
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            sets: [],
            notes: "",
            activeSeconds: Int(hkWorkout.duration),
            usedEquipmentIDs: resolvedEquipment,
            distanceMeters: distanceMeters(for: hkWorkout)
        )

        return WorkoutLog(
            workoutName: exercise.name,
            completedAt: hkWorkout.endDate,
            exercises: [logged],
            notes: "Imported from Apple Health",
            duration: hkWorkout.duration,
            healthKitUUID: hkWorkout.uuid,
            healthKitActivityTypeRaw: hkWorkout.workoutActivityType.rawValue,
            primaryMuscleGroupIDs: exercise.primaryMuscleGroupIDs,
            secondaryMuscleGroupIDs: exercise.secondaryMuscleGroupIDs,
            logEquipmentIDs: resolvedEquipment,
            isIndoor: isIndoor
        )
    }

    /// Pulls total distance (meters) off an `HKWorkout` by checking each known
    /// distance quantity type in turn. `nil` if Apple Health didn't record a
    /// distance for this workout (typical for strength sessions, yoga, etc.).
    private func distanceMeters(for hkWorkout: HKWorkout) -> Double? {
        let ids: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming
        ]
        for id in ids {
            if let stats = hkWorkout.statistics(for: HKQuantityType(id)),
               let qty = stats.sumQuantity() {
                let meters = qty.doubleValue(for: .meter())
                if meters > 0 { return meters }
            }
        }
        return nil
    }

    /// Human-readable label for the activity type — exposed so the import path
    /// can also use it when creating a new `Exercise` from an unrecognized type.
    public func activityDisplayName(for activityType: HKWorkoutActivityType) -> String {
        displayName(for: activityType)
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
