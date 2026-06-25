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
    /// True while the wrist primary session is mirroring back to the
    /// iPhone — set by both `start(...)` (best-effort for watch-initiated
    /// sessions when the phone is reachable) and `startMirrored(config:)`
    /// (always, for phone-driven sessions). Drives whether `end()` needs to
    /// also `stopMirroringToCompanionDevice()`.
    private(set) var isMirroringToPhone: Bool = false
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
    /// simple "duration only" session (single exercise, timer) or a voice
    /// trainer (see `voiceConfig`).
    private(set) var blueprint: WatchWorkoutBlueprint? = nil
    /// Loaded voice trainer config when the user started one from the wrist.
    /// The live UI switches into the trainer runner (round-based line
    /// speaking + rest countdown) when this is non-nil.
    private(set) var voiceConfig: WatchVoiceTrainerConfig? = nil
    /// Loaded timer config when the user started a timer from the wrist.
    /// The live UI switches into the timer runner (phase progression,
    /// count-up/down, AMRAP rounds, warmup/cooldown) when this is non-nil.
    private(set) var timerConfig: WatchTimerConfig? = nil
    /// Index of the item currently being worked through (0-based, walks
    /// `blueprint.items`).
    private(set) var currentItemIndex: Int = 0
    /// Sets the user has logged for the currently-active non-complex item.
    /// Cleared whenever we advance to a new item.
    private(set) var currentItemSets: [WatchLoggedSet] = []
    /// 1-based round counter while we're on a complex item.
    private(set) var complexRound: Int = 1
    /// User-editable reps + weight per exercise within the current complex,
    /// keyed by the blueprint exercise UUID. Initialized from the predefined
    /// set values when we enter the complex and carried across rounds.
    private(set) var complexValues: [String: WatchLoggedSet] = [:]
    /// Completed sets keyed by exercise UUID — accumulated across the whole
    /// session so loggedExercisesForReport can roll them up at the end.
    /// One entry per logged set; complex rounds emit one set per participating
    /// exercise each round.
    private var completedSetsByExerciseID: [String: [WatchLoggedSet]] = [:]
    /// Parallel-ordered list of exercise UUIDs in the order they were first
    /// completed, so the iPhone log preserves the workout's authoring order
    /// rather than dictionary iteration order.
    private var completedExerciseOrder: [String] = []
    /// Display name + exerciseID metadata for each unique exercise touched,
    /// used to assemble loggedExercisesForReport without re-walking items.
    private var exerciseMetadata: [String: (name: String, exerciseID: String)] = [:]

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

    /// Defers to the app-wide `WatchHealthKit` auth gate so all HK types
    /// the wrist needs are bundled into a single consolidated permission
    /// sheet at first launch. Safe to call repeatedly.
    func requestAuthorization() async {
        await WatchHealthKit.shared.requestAuthorization()
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
               blueprint: WatchWorkoutBlueprint? = nil,
               voiceConfig: WatchVoiceTrainerConfig? = nil,
               timerConfig: WatchTimerConfig? = nil) async -> Bool {
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
            self.voiceConfig = voiceConfig
            self.timerConfig = timerConfig
            self.currentItemIndex = 0
            self.currentItemSets = []
            self.complexRound = 1
            self.complexValues = [:]
            self.completedSetsByExerciseID = [:]
            self.completedExerciseOrder = []
            self.exerciseMetadata = [:]
            // If we're starting on a complex item, seed the per-exercise
            // editable values from each one's first predefined set.
            if let blueprint, let first = blueprint.items.first,
               case .complex(let cx) = first {
                seedComplexValues(cx)
            }

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)

            self.startDate = start
            self.heartRate = 0
            self.activeEnergyKcal = 0
            self.isActive = true

            // Best-effort: mirror the watch-initiated session back to the
            // iPhone so the phone-side coordinator can show a live HR HUD.
            // Failure here (phone unreachable, app not installed) is fine —
            // we still run standalone on the wrist.
            do {
                try await session.startMirroringToCompanionDevice()
                self.isMirroringToPhone = true
            } catch {
                self.isMirroringToPhone = false
            }
            return true
        } catch {
            print("❌ Watch workout session start failed: \(error.localizedDescription)")
            clearState()
            return false
        }
    }

    /// Phone-driven entry point. Called from the watch app's
    /// `WKApplicationDelegate.handle(_:)` after the iPhone wakes us via
    /// `HKHealthStore.startWatchApp(toHandle:)`. Spins up the primary
    /// HKWorkoutSession, immediately starts mirroring it back so the iPhone
    /// becomes the mirrored counterpart and starts receiving live HR
    /// samples, then waits for the phone to send the session name across
    /// the remote data channel for the wrist HUD.
    @discardableResult
    func startMirrored(config: HKWorkoutConfiguration) async -> Bool {
        MirrorDiagnostics.log("startMirrored called — activity=\(config.activityType.rawValue) isActive=\(isActive)")
        guard HKHealthStore.isHealthDataAvailable() else {
            MirrorDiagnostics.log("startMirrored: HealthKit unavailable")
            return false
        }
        guard !isActive else {
            MirrorDiagnostics.log("startMirrored: already active — returning")
            return true
        }

        await requestAuthorization()

        let activity = config.activityType
        let rawType: UInt? = activity == .other ? nil : activity.rawValue

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder
            self.activityType = activity
            self.activityTypeRaw = rawType
            // The phone will overwrite this momentarily via a
            // `MirroredSessionMessage.name(...)` payload — until then,
            // fall back to a sensible default so the HUD isn't blank.
            self.displayName = "Workout"
            self.pendingLogName = "Workout"
            self.isLocallyStarted = false
            self.blueprint = nil
            self.voiceConfig = nil
            self.timerConfig = nil
            self.currentItemIndex = 0
            self.currentItemSets = []
            self.complexRound = 1
            self.complexValues = [:]
            self.completedSetsByExerciseID = [:]
            self.completedExerciseOrder = []
            self.exerciseMetadata = [:]

            // Start mirroring BEFORE starting the activity so the phone-side
            // mirror handler fires while the session is still preparing —
            // that way the phone joins as a mirrored client cleanly.
            try await session.startMirroringToCompanionDevice()
            self.isMirroringToPhone = true
            MirrorDiagnostics.log("startMirroringToCompanionDevice ok")

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)

            self.startDate = start
            self.heartRate = 0
            self.activeEnergyKcal = 0
            self.isActive = true
            MirrorDiagnostics.log("startMirrored: session active and mirroring")
            return true
        } catch {
            MirrorDiagnostics.log("Mirrored workout start failed: \(error.localizedDescription)")
            clearState()
            return false
        }
    }

    /// Apply the phone's display-name handshake to a mirrored session.
    /// Called when the iPhone's `MirroredSessionMessage.name(...)` arrives
    /// over the remote data channel.
    func applyMirroredName(_ name: String, activityTypeRaw: UInt?) {
        guard isActive, !isLocallyStarted else { return }
        self.displayName = name
        self.pendingLogName = name
        if let raw = activityTypeRaw {
            self.activityTypeRaw = raw
            self.activityType = HKWorkoutActivityType(rawValue: raw) ?? .other
        }
    }

    /// Ends the live session in response to a phone-driven `MirroredSession
    /// Message.end`. Persists the HKWorkout, sends `endAck` back so the
    /// iPhone WorkoutLog can adopt the UUID, then stops mirroring.
    func endFromRemote() async {
        guard isActive, let session, let builder else { return }

        let endDate = Date()
        session.end()
        do {
            try await builder.endCollection(at: endDate)
        } catch {
            print("❌ Watch workout endCollection failed: \(error.localizedDescription)")
        }
        let uuid: UUID? = await withCheckedContinuation { (cont: CheckedContinuation<UUID?, Never>) in
            builder.finishWorkout { workout, _ in
                cont.resume(returning: workout?.uuid)
            }
        }

        let ack = MirroredSessionMessage.endAck(workoutUUID: uuid?.uuidString)
        if let data = ack.encoded() {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                print("⚠️ Watch workout endAck failed: \(error.localizedDescription)")
            }
        }
        if isMirroringToPhone {
            do { try await session.stopMirroringToCompanionDevice() } catch {
                print("⚠️ Watch workout stopMirroring failed: \(error.localizedDescription)")
            }
        }
        clearState()
    }

    /// Discards the live session in response to a phone-driven `Mirrored
    /// SessionMessage.cancel`. No HKWorkout is written, no log is sent
    /// back, and the mirror is torn down.
    func cancelFromRemote() async {
        guard isActive, let session, let builder else { return }
        let endDate = Date()
        session.end()
        do {
            try await builder.endCollection(at: endDate)
        } catch {
            print("❌ Watch workout endCollection (cancel) failed: \(error.localizedDescription)")
        }
        builder.discardWorkout()
        if isMirroringToPhone {
            do { try await session.stopMirroringToCompanionDevice() } catch {
                print("⚠️ Watch workout stopMirroring (cancel) failed: \(error.localizedDescription)")
            }
        }
        clearState()
    }

    /// Ends the live workout session and returns the saved HKWorkout's UUID
    /// (nil on failure). The caller should send this UUID back to the iPhone
    /// so its WorkoutLog can be tagged for dedup.
    func end() async -> UUID? {
        guard isActive, let session, let builder else { return nil }

        let wasMirroring = isMirroringToPhone
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

        // Tear down the mirror — for watch-initiated sessions that
        // opportunistically mirrored to the iPhone, this lets the
        // phone-side coordinator clear its HUD.
        if wasMirroring {
            do { try await session.stopMirroringToCompanionDevice() } catch {
                print("⚠️ Watch workout stopMirroring (local end) failed: \(error.localizedDescription)")
            }
        }

        clearState()
        return uuid
    }

    /// Cancels the live workout — stops the HKWorkoutSession and discards the
    /// builder so no HKWorkout is written to Apple Health and no log is sent
    /// back to the iPhone. Pair with the X-tap confirmation flow; the Stop /
    /// Finish buttons stay on `end()`.
    func cancel() async {
        guard isActive, let session, let builder else { return }
        let wasMirroring = isMirroringToPhone
        let endDate = Date()
        session.end()
        do {
            try await builder.endCollection(at: endDate)
        } catch {
            print("❌ Watch workout endCollection (cancel) failed: \(error.localizedDescription)")
        }
        builder.discardWorkout()
        if wasMirroring {
            do { try await session.stopMirroringToCompanionDevice() } catch {
                print("⚠️ Watch workout stopMirroring (cancel) failed: \(error.localizedDescription)")
            }
        }
        clearState()
    }

    // MARK: - Runner controls (for blueprint-driven sessions)

    /// The item currently being worked through (single exercise or complex).
    /// Returns nil when the blueprint isn't loaded or every item is done.
    func currentItem() -> WatchBlueprintItem? {
        guard let blueprint else { return nil }
        guard currentItemIndex < blueprint.items.count else { return nil }
        return blueprint.items[currentItemIndex]
    }

    /// The active exercise when the current item is a single exercise.
    /// nil when the item is a complex (use `currentComplex()` instead).
    func currentExercise() -> WatchBlueprintExercise? {
        guard case .exercise(let ex) = currentItem() else { return nil }
        return ex
    }

    /// The active complex when the current item is a complex round group.
    func currentComplex() -> WatchBlueprintComplex? {
        guard case .complex(let cx) = currentItem() else { return nil }
        return cx
    }

    /// Sets the user has already logged for the active non-complex item.
    func loggedSetCount() -> Int { currentItemSets.count }

    /// Planned set count for the active non-complex item.
    func plannedSetCount() -> Int {
        currentExercise()?.predefinedSets.count ?? 0
    }

    /// Predefined target for the next set on the active non-complex item.
    func nextPredefinedSet() -> WatchPredefinedSet? {
        guard let ex = currentExercise() else { return nil }
        let idx = loggedSetCount()
        guard idx < ex.predefinedSets.count else { return nil }
        return ex.predefinedSets[idx]
    }

    /// Records a completed set for the active non-complex item.
    func logSet(reps: Int, weight: Double) {
        guard let ex = currentExercise() else { return }
        let set = WatchLoggedSet(reps: reps, weight: weight)
        currentItemSets.append(set)
        recordCompletedSet(set, for: ex)
    }

    /// Returns the previously-logged set at `index` within the active item,
    /// or nil if out of range. Drives the prev/next chevron preview.
    func loggedSetForCurrentItem(at index: Int) -> WatchLoggedSet? {
        guard index >= 0, index < currentItemSets.count else { return nil }
        return currentItemSets[index]
    }

    /// Replaces a previously-logged set at `index` within the active item.
    /// Also rewrites the trailing-aligned entry in completedSetsByExerciseID
    /// so the final report and per-exercise tracking stay consistent.
    func updateLoggedSet(at index: Int, reps: Int, weight: Double) {
        guard let ex = currentExercise() else { return }
        guard index >= 0, index < currentItemSets.count else { return }
        let updated = WatchLoggedSet(reps: reps, weight: weight)
        currentItemSets[index] = updated
        // The trailing currentItemSets.count entries in completedSetsByExerciseID
        // line up 1:1 with currentItemSets — splice the matching entry.
        let exID = ex.exerciseID
        if var all = completedSetsByExerciseID[exID] {
            let startOffset = all.count - currentItemSets.count
            let targetIndex = startOffset + index
            if targetIndex >= 0, targetIndex < all.count {
                all[targetIndex] = updated
                completedSetsByExerciseID[exID] = all
            }
        }
    }

    /// Advances past the current item — used by the runner when the user taps
    /// "Next" after finishing a single exercise. For complex items, callers
    /// should drive `completeComplexRound()` instead and advance only after
    /// the last round.
    func advanceToNextItem() {
        currentItemIndex += 1
        currentItemSets = []
        complexRound = 1
        complexValues = [:]
        // Seed values for a newly-entered complex item.
        if case .complex(let cx) = currentItem() { seedComplexValues(cx) }
    }

    /// Legacy shim — old callers expected this name. Forwards to the items
    /// walker so existing controller code keeps compiling.
    func advanceToNextExercise() { advanceToNextItem() }

    func isWorkoutComplete() -> Bool {
        guard let blueprint else { return false }
        return currentItemIndex >= blueprint.items.count
    }

    /// Aggregated per-exercise log of everything completed so far, preserving
    /// the order each exercise was first touched.
    func loggedExercisesForReport() -> [WatchLoggedExercise] {
        completedExerciseOrder.compactMap { exID in
            guard let sets = completedSetsByExerciseID[exID], !sets.isEmpty,
                  let meta = exerciseMetadata[exID] else { return nil }
            return WatchLoggedExercise(
                exerciseID: meta.exerciseID,
                exerciseName: meta.name,
                activeSeconds: 0,
                sets: sets
            )
        }
    }

    // MARK: - Complex controls

    /// Update the user-editable reps/weight for one exercise within the
    /// current complex. Values persist across rounds until the user changes
    /// them again.
    func setComplexValue(forExerciseID id: String, reps: Int, weight: Double) {
        guard case .complex = currentItem() else { return }
        complexValues[id] = WatchLoggedSet(reps: reps, weight: weight)
    }

    /// Records one set per participating exercise using the current
    /// `complexValues`, then either advances the round counter or moves past
    /// the complex when the last round is done.
    /// - Returns: true if the complex is fully complete (caller can advance UI
    ///   accordingly), false if more rounds remain.
    @discardableResult
    func completeComplexRound() -> Bool {
        guard let cx = currentComplex() else { return false }
        for ex in cx.exercises {
            let value = complexValues[ex.id]
                ?? WatchLoggedSet(reps: ex.predefinedSets.first?.reps ?? 0,
                                  weight: ex.predefinedSets.first?.weight ?? 0)
            recordCompletedSet(value, for: ex)
        }
        if complexRound >= cx.rounds {
            advanceToNextItem()
            return true
        }
        complexRound += 1
        return false
    }

    // MARK: - Private helpers

    private func seedComplexValues(_ cx: WatchBlueprintComplex) {
        for ex in cx.exercises {
            let first = ex.predefinedSets.first
            complexValues[ex.id] = WatchLoggedSet(
                reps: first?.reps ?? 0,
                weight: first?.weight ?? 0
            )
        }
    }

    private func recordCompletedSet(_ set: WatchLoggedSet, for ex: WatchBlueprintExercise) {
        if exerciseMetadata[ex.exerciseID] == nil {
            exerciseMetadata[ex.exerciseID] = (name: ex.name, exerciseID: ex.exerciseID)
            completedExerciseOrder.append(ex.exerciseID)
        }
        completedSetsByExerciseID[ex.exerciseID, default: []].append(set)
    }

    private func clearState() {
        session = nil
        builder = nil
        isActive = false
        isLocallyStarted = false
        isMirroringToPhone = false
        startDate = nil
        heartRate = 0
        activeEnergyKcal = 0
        displayName = ""
        pendingLogName = ""
        activityType = .other
        activityTypeRaw = nil
        blueprint = nil
        voiceConfig = nil
        timerConfig = nil
        currentItemIndex = 0
        currentItemSets = []
        complexRound = 1
        complexValues = [:]
        completedSetsByExerciseID = [:]
        completedExerciseOrder = []
        exerciseMetadata = [:]
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

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        // HealthKit batches incoming payloads when the watch app is
        // suspended — walk in arrival order so a queued "cancel" still
        // wins over an earlier "end" from the same batch.
        Task { @MainActor in
            for blob in data {
                guard let message = MirroredSessionMessage.decode(blob) else { continue }
                await self.handleRemote(message)
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didDisconnectFromRemoteDeviceWithError error: (any Error)?) {
        // Phone-driven session lost its mirror partner. The wrist session
        // can continue running locally (no log will sync back), but for the
        // mirrored-flow we treat this as the end and tear down the wrist
        // UI so the user isn't stranded on the cover.
        Task { @MainActor in
            if !self.isLocallyStarted {
                await self.cancelFromRemote()
            }
        }
    }

    @MainActor
    private func handleRemote(_ message: MirroredSessionMessage) async {
        switch message {
        case .name(let n, let raw):
            applyMirroredName(n, activityTypeRaw: raw)
        case .end:
            await endFromRemote()
        case .cancel:
            await cancelFromRemote()
        case .endAck:
            // Watch never receives this — it's the watch's reply to a
            // phone-driven end. Safe to ignore on the watch side.
            break
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
