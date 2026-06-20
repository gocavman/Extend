////
////  WatchWorkoutSessionManager.swift
////  ExtendWatch
////
////  Owns the live HKWorkoutSession on the Watch. Started/ended remotely by
////  the iPhone via WatchConnectivity so a workout begun in the iOS app
////  collects real heart rate and calories on the Watch — yielding a single
////  authoritative HKWorkout instead of an iPhone-side estimate alongside a
////  separate Watch-native session.
////

import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class WatchWorkoutSessionManager: NSObject {

    static let shared = WatchWorkoutSessionManager()

    // MARK: - Observable state

    /// True while a session is running.
    private(set) var isActive: Bool = false
    /// True when this session was started on the watch itself (vs. driven by
    /// the paired iPhone). Local sessions get a Finish button; remote ones
    /// are ended by the iPhone.
    private(set) var isLocallyStarted: Bool = false
    /// Display name shown on the live UI.
    private(set) var displayName: String = ""
    /// Name used when forwarding the completed log back to the iPhone — set
    /// only for locally-started sessions.
    private(set) var pendingLogName: String = ""
    /// Activity type for the current session.
    private(set) var activityType: HKWorkoutActivityType = .other
    /// Activity type raw value, retained so the watch can include it on the
    /// log sent back to the iPhone.
    private(set) var activityTypeRaw: UInt? = nil
    /// Live values.
    private(set) var heartRate: Double = 0
    private(set) var activeEnergyKcal: Double = 0
    /// Session start date — driver for the live duration label.
    private(set) var startDate: Date?
    /// Loaded blueprint when the user started a multi-exercise workout. When
    /// set, the live UI switches into the set-by-set runner; nil means a
    /// simple "duration only" session (single exercise, timer, voice trainer).
    private(set) var blueprint: WatchWorkoutBlueprint? = nil
    /// Index of the exercise currently being worked through (0-based).
    private(set) var currentExerciseIndex: Int = 0
    /// Sets the user has logged for each exercise in `blueprint.exercises`.
    /// Index is parallel to blueprint.exercises.
    private(set) var loggedSetsPerExercise: [[WatchLoggedSet]] = []

    // MARK: - Private

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    /// Pending reply continuation for an active end-workout request — resumed
    /// once the workout finishes and we have the HKWorkout UUID (or nil on
    /// failure).
    private var endContinuation: CheckedContinuation<UUID?, Never>?

    private override init() { super.init() }

    // MARK: - Authorization

    /// Requests live-workout HK permissions on top of the watch app's existing
    /// step/distance/water reads. Safe to call repeatedly — iOS won't re-prompt
    /// for types already decided.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]
        let read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning)
        ]
        try? await store.requestAuthorization(toShare: share, read: read)
    }

    // MARK: - Start / end

    /// Begins a live workout session for the given activity type. Returns true
    /// if the session was successfully started.
    /// - Parameter isLocal: true when started by the user tapping on the
    ///   watch itself; false when driven by the paired iPhone. Local sessions
    ///   are ended by the user via a Finish button and the result is forwarded
    ///   back to the iPhone as a new WorkoutLog.
    /// - Parameter logName: optional override for the WorkoutLog name when the
    ///   plan item's log key differs from its display name (e.g. "Trainer – X").
    /// - Parameter blueprint: optional flat workout blueprint. When set, the
    ///   live UI switches into a set-by-set runner and the resulting log
    ///   includes per-exercise/per-set detail sent back to the iPhone.
    @discardableResult
    func start(activityTypeRaw: UInt?,
               name: String,
               isLocal: Bool = false,
               logName: String? = nil,
               blueprint: WatchWorkoutBlueprint? = nil) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard !isActive else { return true }

        await requestAuthorization()

        let type: HKWorkoutActivityType = {
            guard let raw = activityTypeRaw, raw != 0,
                  let t = HKWorkoutActivityType(rawValue: raw) else { return .other }
            return t
        }()
        let config = HKWorkoutConfiguration()
        config.activityType = type
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder
            self.activityType = type
            self.activityTypeRaw = activityTypeRaw
            self.displayName = name
            self.pendingLogName = logName ?? name
            self.isLocallyStarted = isLocal
            self.blueprint = blueprint
            self.currentExerciseIndex = 0
            self.loggedSetsPerExercise = Array(
                repeating: [],
                count: blueprint?.exercises.count ?? 0
            )

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)

            self.startDate = start
            self.heartRate = 0
            self.activeEnergyKcal = 0
            self.isActive = true
            return true
        } catch {
            print("❌ Watch workout session start failed: \(error.localizedDescription)")
            clearState()
            return false
        }
    }

    /// Ends the live workout session and returns the saved HKWorkout's UUID
    /// (nil on failure). The caller should send this UUID back to the iPhone
    /// so its WorkoutLog can be tagged for dedup.
    func end() async -> UUID? {
        guard isActive, let session, let builder else { return nil }

        let endDate = Date()
        session.end()
        do {
            try await builder.endCollection(at: endDate)
        } catch {
            print("❌ Watch workout endCollection failed: \(error.localizedDescription)")
        }

        // finishWorkout() returns when the delegate confirms it's saved.
        let uuid: UUID? = await withCheckedContinuation { (cont: CheckedContinuation<UUID?, Never>) in
            endContinuation = cont
            builder.finishWorkout { workout, _ in
                Task { @MainActor in
                    self.endContinuation?.resume(returning: workout?.uuid)
                    self.endContinuation = nil
                }
            }
        }

        clearState()
        return uuid
    }

    // MARK: - Runner controls (for blueprint-driven sessions)

    /// Returns the exercise currently being worked through. nil when no
    /// blueprint is loaded or when all exercises have been completed.
    func currentExercise() -> WatchBlueprintExercise? {
        guard let blueprint else { return nil }
        guard currentExerciseIndex < blueprint.exercises.count else { return nil }
        return blueprint.exercises[currentExerciseIndex]
    }

    /// Number of sets the user has already logged for the current exercise.
    func loggedSetCount() -> Int {
        guard currentExerciseIndex < loggedSetsPerExercise.count else { return 0 }
        return loggedSetsPerExercise[currentExerciseIndex].count
    }

    /// Total planned sets for the current exercise (predefined count).
    func plannedSetCount() -> Int {
        currentExercise()?.predefinedSets.count ?? 0
    }

    /// Returns the predefined target for the next set on the current exercise
    /// — used to pre-fill reps + weight before the user adjusts with Crown.
    func nextPredefinedSet() -> WatchPredefinedSet? {
        guard let ex = currentExercise() else { return nil }
        let idx = loggedSetCount()
        guard idx < ex.predefinedSets.count else { return nil }
        return ex.predefinedSets[idx]
    }

    /// Records a completed set for the current exercise. Caller advances to
    /// the next exercise via `advanceToNextExercise()` when ready.
    func logSet(reps: Int, weight: Double) {
        guard currentExerciseIndex < loggedSetsPerExercise.count else { return }
        loggedSetsPerExercise[currentExerciseIndex].append(
            WatchLoggedSet(reps: reps, weight: weight)
        )
    }

    /// Moves to the next exercise. Caller should check `isWorkoutComplete()`
    /// after advancing.
    func advanceToNextExercise() {
        currentExerciseIndex += 1
    }

    /// True when every exercise in the blueprint has at least its planned set
    /// count logged, or when the user has stepped past the last exercise.
    func isWorkoutComplete() -> Bool {
        guard let blueprint else { return false }
        return currentExerciseIndex >= blueprint.exercises.count
    }

    /// Snapshot of everything logged so far, for shipping to the iPhone.
    func loggedExercisesForReport() -> [WatchLoggedExercise] {
        guard let blueprint else { return [] }
        return blueprint.exercises.enumerated().compactMap { idx, ex in
            let sets = idx < loggedSetsPerExercise.count ? loggedSetsPerExercise[idx] : []
            guard !sets.isEmpty else { return nil }
            return WatchLoggedExercise(
                exerciseID: ex.exerciseID,
                exerciseName: ex.name,
                activeSeconds: 0,
                sets: sets
            )
        }
    }

    private func clearState() {
        session = nil
        builder = nil
        isActive = false
        isLocallyStarted = false
        startDate = nil
        heartRate = 0
        activeEnergyKcal = 0
        displayName = ""
        pendingLogName = ""
        activityType = .other
        activityTypeRaw = nil
        blueprint = nil
        currentExerciseIndex = 0
        loggedSetsPerExercise = []
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ Workout session failed: \(error.localizedDescription)")
            self.endContinuation?.resume(returning: nil)
            self.endContinuation = nil
            self.clearState()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let qType = type as? HKQuantityType,
                      let stats = workoutBuilder.statistics(for: qType) else { continue }
                switch qType {
                case HKQuantityType(.heartRate):
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    if let v = stats.mostRecentQuantity()?.doubleValue(for: unit) {
                        self.heartRate = v
                    }
                case HKQuantityType(.activeEnergyBurned):
                    if let v = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.activeEnergyKcal = v
                    }
                default:
                    break
                }
            }
        }
    }
}
