import Foundation
import Observation
import WidgetKit

// MARK: - Plan Package (self-contained export/import format)

/// A portable bundle containing training plans plus all referenced workouts, exercises,
/// equipment, muscle groups, voice trainer configs, and timer configs.
/// UUIDs are only used for internal package consistency; import resolves everything by name.
struct PlanPackage: Codable {
    var plans: [TrainingPlan]
    var workouts: [Workout]
    var exercises: [Exercise]
    var equipment: [Equipment]
    var muscleGroups: [MuscleGroup]
    var voiceConfigs: [VoiceTrainerConfig]
    var timerConfigs: [TimerConfig]
}

@Observable
final class TrainingPlanState {
    static let shared = TrainingPlanState()

    var plans: [TrainingPlan] = []
    var activePlanID: UUID? = nil

    private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard
    private let plansKey = "training_plans_data"
    private let activeKey = "training_active_plan_id"

    init() {
        load()
    }

    // MARK: - Computed

    var activePlan: TrainingPlan? {
        get { plans.first { $0.id == activePlanID } }
    }

    /// Returns the PlanDay for today from the active plan, or nil if no active plan.
    func todayPlanDay() -> PlanDay? {
        activePlan?.planDay(for: Date())
    }

    /// Returns the PlanDay for a given date from the active plan,
    /// but only if the date falls within the plan's active date range.
    func planDay(for date: Date) -> PlanDay? {
        guard let plan = activePlan else { return nil }
        guard plan.isActive(on: date) else { return nil }
        let day = plan.planDay(for: date)
        return day.isEmpty ? nil : day
    }

    // MARK: - Mutations

    func addPlan(_ plan: TrainingPlan) {
        plans.append(plan)
        if activePlanID == nil { activePlanID = plan.id }
        save()
    }

    func updatePlan(_ plan: TrainingPlan) {
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
            save()
        }
    }

    func removePlan(id: UUID) {
        plans.removeAll { $0.id == id }
        if activePlanID == id { activePlanID = plans.first?.id }
        save()
    }

    func setActive(id: UUID?) {
        activePlanID = id
        saveActiveID()
        refreshWidgetSnapshot()
    }

    func resetPlans() {
        plans = []
        activePlanID = nil
        defaults.removeObject(forKey: plansKey)
        defaults.removeObject(forKey: activeKey)
    }

    // MARK: - Export / Import

    func exportData(
        for plansToExport: [TrainingPlan],
        workoutsState: WorkoutsState,
        exercisesState: ExercisesState,
        equipmentState: EquipmentState,
        muscleGroupsState: MuscleGroupsState,
        voiceTrainerState: VoiceTrainerState,
        timerState: TimerState
    ) -> Data? {
        // Collect all referenced IDs across every plan day
        var workoutIDs = Set<UUID>()
        var exerciseIDs = Set<UUID>()
        var voiceIDs = Set<UUID>()
        var timerIDs = Set<UUID>()

        for plan in plansToExport {
            let allDays = plan.template + plan.weekOverrides.values.flatMap { $0 }
            for day in allDays {
                workoutIDs.formUnion(day.workoutIDs)
                exerciseIDs.formUnion(day.exerciseIDs)
                voiceIDs.formUnion(day.voiceActivityIDs)
                timerIDs.formUnion(day.timerIDs)
            }
        }

        let referencedWorkouts = workoutsState.workouts.filter { workoutIDs.contains($0.id) }

        // Collect exercises referenced by the workouts too
        let workoutExerciseIDs = Set(referencedWorkouts.flatMap { w in
            w.items.compactMap { item -> UUID? in
                if case .exercise(let we) = item { return we.exerciseID }
                return nil
            }
        })
        exerciseIDs.formUnion(workoutExerciseIDs)

        let referencedExercises = exercisesState.exercises.filter { exerciseIDs.contains($0.id) }
        let equipIDs = Set(referencedExercises.flatMap { $0.equipmentIDs })
        let muscleIDs = Set(referencedExercises.flatMap { $0.primaryMuscleGroupIDs + $0.secondaryMuscleGroupIDs })

        let package = PlanPackage(
            plans: plansToExport,
            workouts: referencedWorkouts,
            exercises: referencedExercises,
            equipment: equipmentState.items.filter { equipIDs.contains($0.id) },
            muscleGroups: muscleGroupsState.groups.filter { muscleIDs.contains($0.id) },
            voiceConfigs: voiceTrainerState.savedConfigurations.filter { voiceIDs.contains($0.id) },
            timerConfigs: timerState.configs.filter { timerIDs.contains($0.id) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(package)
    }

    @discardableResult
    func importPlans(
        from data: Data,
        workoutsState: WorkoutsState,
        exercisesState: ExercisesState,
        equipmentState: EquipmentState,
        muscleGroupsState: MuscleGroupsState,
        voiceTrainerState: VoiceTrainerState,
        timerState: TimerState
    ) throws -> Int {
        let package = try JSONDecoder().decode(PlanPackage.self, from: data)

        // ── 1. Resolve muscle groups ──────────────────────────────────
        var muscleIDMap: [UUID: UUID] = [:]
        for mg in package.muscleGroups {
            if let existing = muscleGroupsState.groups.first(where: {
                $0.name.localizedCaseInsensitiveCompare(mg.name) == .orderedSame
            }) {
                muscleIDMap[mg.id] = existing.id
            } else {
                let fresh = MuscleGroup(name: mg.name)
                muscleGroupsState.groups.append(fresh)
                muscleIDMap[mg.id] = fresh.id
            }
        }

        // ── 2. Resolve equipment ──────────────────────────────────────
        var equipIDMap: [UUID: UUID] = [:]
        for eq in package.equipment {
            if let existing = equipmentState.items.first(where: {
                $0.name.localizedCaseInsensitiveCompare(eq.name) == .orderedSame
            }) {
                equipIDMap[eq.id] = existing.id
            } else {
                let fresh = Equipment(name: eq.name)
                equipmentState.items.append(fresh)
                equipIDMap[eq.id] = fresh.id
            }
        }

        // ── 3. Resolve exercises ──────────────────────────────────────
        var exerciseIDMap: [UUID: UUID] = [:]
        for ex in package.exercises {
            if let existing = exercisesState.exercises.first(where: {
                $0.name.localizedCaseInsensitiveCompare(ex.name) == .orderedSame
            }) {
                exerciseIDMap[ex.id] = existing.id
            } else {
                let fresh = Exercise(
                    name: ex.name,
                    notes: ex.notes,
                    primaryMuscleGroupIDs: ex.primaryMuscleGroupIDs.map { muscleIDMap[$0] ?? $0 },
                    secondaryMuscleGroupIDs: ex.secondaryMuscleGroupIDs.map { muscleIDMap[$0] ?? $0 },
                    equipmentIDs: ex.equipmentIDs.map { equipIDMap[$0] ?? $0 },
                    defaultEquipmentIDs: ex.defaultEquipmentIDs.map { equipIDMap[$0] ?? $0 },
                    healthKitActivityType: ex.healthKitActivityType
                )
                exercisesState.addExercise(fresh)
                exerciseIDMap[ex.id] = fresh.id
            }
        }

        // ── 4. Resolve workouts ───────────────────────────────────────
        var workoutIDMap: [UUID: UUID] = [:]
        for original in package.workouts {
            if let existing = workoutsState.workouts.first(where: {
                $0.name.localizedCaseInsensitiveCompare(original.name) == .orderedSame
            }) {
                workoutIDMap[original.id] = existing.id
            } else {
                let remappedItems: [WorkoutItem] = original.items.map { item in
                    guard case .exercise(let we) = item else { return item }
                    return .exercise(WorkoutExercise(
                        id: UUID(),
                        exerciseID: exerciseIDMap[we.exerciseID] ?? we.exerciseID,
                        loopID: we.loopID,
                        complexID: we.complexID,
                        predefinedSets: we.predefinedSets,
                        defaultEquipmentIDs: we.defaultEquipmentIDs.map { equipIDMap[$0] ?? $0 }
                    ))
                }
                let fresh = Workout(
                    id: UUID(),
                    name: original.name,
                    notes: original.notes,
                    items: remappedItems,
                    healthKitActivityType: original.healthKitActivityType,
                    loops: original.loops,
                    complexes: original.complexes,
                    warmupSeconds: original.warmupSeconds,
                    cooldownSeconds: original.cooldownSeconds,
                    showNotes: original.showNotes
                )
                workoutsState.addWorkout(fresh)
                workoutIDMap[original.id] = fresh.id
            }
        }

        // ── 5. Resolve voice trainer configs ──────────────────────────
        var voiceIDMap: [UUID: UUID] = [:]
        for vc in package.voiceConfigs {
            if let existing = voiceTrainerState.savedConfigurations.first(where: {
                $0.name.localizedCaseInsensitiveCompare(vc.name) == .orderedSame
            }) {
                voiceIDMap[vc.id] = existing.id
            } else {
                var fresh = vc
                fresh = VoiceTrainerConfig(
                    id: UUID(),
                    name: vc.name,
                    notes: vc.notes,
                    text: vc.text,
                    roundLength: vc.roundLength,
                    restLength: vc.restLength,
                    delayBetweenLines: vc.delayBetweenLines,
                    numberOfRounds: vc.numberOfRounds,
                    randomOrder: vc.randomOrder,
                    cooldownPeriod: vc.cooldownPeriod,
                    workoutStartWarning: vc.workoutStartWarning,
                    restEndWarning: vc.restEndWarning,
                    isFavorite: vc.isFavorite,
                    healthKitActivityType: vc.healthKitActivityType,
                    primaryMuscleGroupIDs: vc.primaryMuscleGroupIDs.map { muscleIDMap[$0] ?? $0 },
                    secondaryMuscleGroupIDs: vc.secondaryMuscleGroupIDs.map { muscleIDMap[$0] ?? $0 },
                    equipmentIDs: vc.equipmentIDs.map { equipIDMap[$0] ?? $0 }
                )
                voiceTrainerState.savedConfigurations.append(fresh)
                voiceTrainerState.saveConfigurations()
                voiceIDMap[vc.id] = fresh.id
            }
        }

        // ── 6. Resolve timer configs ──────────────────────────────────
        var timerIDMap: [UUID: UUID] = [:]
        for tc in package.timerConfigs {
            if let existing = timerState.configs.first(where: {
                $0.name.localizedCaseInsensitiveCompare(tc.name) == .orderedSame
            }) {
                timerIDMap[tc.id] = existing.id
            } else {
                let fresh = TimerConfig(
                    id: UUID(),
                    name: tc.name,
                    notes: tc.notes,
                    type: tc.type,
                    direction: tc.direction,
                    duration: tc.duration,
                    restDuration: tc.restDuration,
                    rounds: tc.rounds,
                    warmupDuration: tc.warmupDuration,
                    cooldownDuration: tc.cooldownDuration,
                    ladderStep: tc.ladderStep,
                    ladderPeakRounds: tc.ladderPeakRounds,
                    isFavorite: tc.isFavorite,
                    healthKitActivityType: tc.healthKitActivityType
                )
                timerState.addConfig(fresh)
                timerIDMap[tc.id] = fresh.id
            }
        }

        // ── 7. Import plans, remapping all IDs ────────────────────────
        var count = 0
        for original in package.plans {
            let freshID = UUID()

            func remapDay(_ day: PlanDay) -> PlanDay {
                PlanDay(
                    id: UUID(),
                    dayOfWeek: day.dayOfWeek,
                    workoutIDs: day.workoutIDs.map { workoutIDMap[$0] ?? $0 },
                    exerciseIDs: day.exerciseIDs.map { exerciseIDMap[$0] ?? $0 },
                    voiceActivityIDs: day.voiceActivityIDs.map { voiceIDMap[$0] ?? $0 },
                    timerIDs: day.timerIDs.map { timerIDMap[$0] ?? $0 },
                    note: day.note
                )
            }

            var fresh = TrainingPlan(
                id: freshID,
                name: uniquePlanName(for: original.name),
                startDate: original.startDate,
                weeks: original.weeks
            )
            fresh.template = original.template.map { remapDay($0) }
            fresh.weekOverrides = Dictionary(uniqueKeysWithValues:
                original.weekOverrides.map { key, days in
                    (key, days.map { remapDay($0) })
                }
            )
            plans.append(fresh)
            count += 1
        }
        save()
        return count
    }

    private func uniquePlanName(for name: String) -> String {
        var candidate = name
        var suffix = 2
        while plans.contains(where: { $0.name == candidate }) {
            candidate = "\(name) (\(suffix))"
            suffix += 1
        }
        return candidate
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: plansKey),
           let decoded = try? JSONDecoder().decode([TrainingPlan].self, from: data) {
            plans = decoded
        }
        if let uuidString = defaults.string(forKey: activeKey),
           let uuid = UUID(uuidString: uuidString) {
            activePlanID = uuid
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(plans) {
            defaults.set(encoded, forKey: plansKey)
        }
        saveActiveID()
        refreshWidgetSnapshot()
        CloudKitSyncEngine.shared.push(.trainingPlans)
    }

    /// Resolves today's plan items into display names and writes the widget snapshot.
    func refreshWidgetSnapshot() {
        // The Watch library/recents projection runs unconditionally — a user
        // without an active plan still browses workouts/exercises/timers/voice
        // trainers from the wrist, so the library snapshot must stay current
        // even when the plan-specific paths short-circuit below.
        refreshWatchLibrary()
        refreshTodayLogCount()

        guard let plan = activePlan else {
            writeWidgetSnapshot(planName: nil, items: [])
            // Clear the watch's multi-day window too so a deleted/deactivated
            // plan doesn't keep showing on the wrist.
            refreshMultiDaySnapshots()
            return
        }
        let pd = planDay(for: Date())
        guard let pd else {
            writeWidgetSnapshot(planName: plan.name, items: [])
            // Today not in the plan's window (or a rest day) — still push the
            // ±7-day window so the Watch can show upcoming/past days, otherwise
            // adding a plan whose start date isn't today would never reach the
            // watch.
            refreshMultiDaySnapshots()
            return
        }
        let wDefaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

        // Build the set of today's completed log names (same logic as dashboard tile)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var completedNames: Set<String> = []
        if let logData = wDefaults.data(forKey: "workout_logs"),
           let logs = try? JSONDecoder().decode([WorkoutLog].self, from: logData) {
            let todayLogs = logs.filter { cal.isDate($0.completedAt, inSameDayAs: today) }
            completedNames = Set(todayLogs.map { $0.workoutName })
        }

        var items: [WidgetPlanItem] = []

        // Workouts
        if let data = wDefaults.data(forKey: "workouts_data"),
           let workouts = try? JSONDecoder().decode([Workout].self, from: data) {
            items += pd.workoutIDs.compactMap { id in
                workouts.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "dumbbell.fill",
                                  isCompleted: completedNames.contains($0.name),
                                  hkActivityTypeRaw: $0.healthKitActivityType,
                                  logName: $0.name,
                                  kind: "workout",
                                  sourceID: $0.id.uuidString)
                }
            }
        }
        // Exercises
        if let data = wDefaults.data(forKey: "exercises_data"),
           let exercises = try? JSONDecoder().decode([Exercise].self, from: data) {
            items += pd.exerciseIDs.compactMap { id in
                exercises.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "figure.strengthtraining.traditional",
                                  isCompleted: completedNames.contains($0.name),
                                  hkActivityTypeRaw: $0.healthKitActivityType,
                                  logName: $0.name,
                                  kind: "exercise",
                                  sourceID: $0.id.uuidString)
                }
            }
        }
        // Voice trainers
        if let data = wDefaults.data(forKey: "VoiceTrainerConfigs"),
           let configs = try? JSONDecoder().decode([VoiceTrainerConfig].self, from: data) {
            items += pd.voiceActivityIDs.compactMap { id in
                configs.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "waveform",
                                  isCompleted: completedNames.contains("Trainer – \($0.name)"),
                                  hkActivityTypeRaw: $0.healthKitActivityType,
                                  logName: "Trainer – \($0.name)",
                                  kind: "voice",
                                  sourceID: $0.id.uuidString)
                }
            }
        }
        // Timers
        if let data = wDefaults.data(forKey: "timer_configs"),
           let configs = try? JSONDecoder().decode([TimerConfig].self, from: data) {
            items += pd.timerIDs.compactMap { id in
                configs.first { $0.id == id }.map { c in
                    let displayName = c.name.isEmpty ? c.type.rawValue : c.name
                    return WidgetPlanItem(name: displayName, icon: c.type.iconName,
                                         isCompleted: completedNames.contains("\(c.type.rawValue) – \(displayName)"),
                                         hkActivityTypeRaw: c.healthKitActivityType,
                                         logName: "\(c.type.rawValue) – \(displayName)",
                                         kind: "timer",
                                         sourceID: c.id.uuidString)
                }
            }
        }

        writeWidgetSnapshot(planName: plan.name, items: items, note: pd.note)

        // Also write a ±7-day window so the Watch app can browse nearby days.
        refreshMultiDaySnapshots()
    }

    /// Builds plan snapshots for today ±7 days and writes them to the App Group
    /// under the "widget_plan_multiday" key for the Watch app's day-browsing view.
    private func refreshMultiDaySnapshots() {
        guard let plan = activePlan else {
            writeMultiDaySnapshots([])
            // Clear the watch too — without this, deactivating a plan leaves
            // stale snapshots on the wrist.
            WatchConnectivityReceiver.shared.sendPlanUpdate(multidaySnapshots: [])
            return
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let wDefaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

        // Decode all supporting data once
        let workouts  = (wDefaults.data(forKey: "workouts_data").flatMap  { try? JSONDecoder().decode([Workout].self,           from: $0) }) ?? []
        let exercises = (wDefaults.data(forKey: "exercises_data").flatMap { try? JSONDecoder().decode([Exercise].self,          from: $0) }) ?? []
        let voices    = (wDefaults.data(forKey: "VoiceTrainerConfigs").flatMap { try? JSONDecoder().decode([VoiceTrainerConfig].self, from: $0) }) ?? []
        let timers    = (wDefaults.data(forKey: "timer_configs").flatMap  { try? JSONDecoder().decode([TimerConfig].self,        from: $0) }) ?? []
        let logs      = (wDefaults.data(forKey: "workout_logs").flatMap   { try? JSONDecoder().decode([WorkoutLog].self,         from: $0) }) ?? []

        var snapshots: [WidgetPlanSnapshot] = []
        for offset in -7...7 {
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            guard plan.isActive(on: date) else { continue }
            let pd = plan.planDay(for: date)

            let trimmedNote = pd.note.trimmingCharacters(in: .whitespacesAndNewlines)
            if pd.isEmpty {
                // PlanDay.isEmpty checks items AND note, so this branch only
                // runs when there is truly nothing scheduled.
                snapshots.append(WidgetPlanSnapshot(planName: plan.name, date: date, items: [], isRestDay: true, note: nil))
                continue
            }

            // Build completed set for this date
            let dayLogs = logs.filter { cal.isDate($0.completedAt, inSameDayAs: date) }
            let completedNames = Set(dayLogs.map { $0.workoutName })

            var items: [WidgetPlanItem] = []
            items += pd.workoutIDs.compactMap { id in
                workouts.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "dumbbell.fill",
                                  isCompleted: completedNames.contains($0.name),
                                  hkActivityTypeRaw: $0.healthKitActivityType,
                                  logName: $0.name,
                                  kind: "workout",
                                  sourceID: $0.id.uuidString)
                }
            }
            items += pd.exerciseIDs.compactMap { id in
                exercises.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "figure.strengthtraining.traditional",
                                  isCompleted: completedNames.contains($0.name),
                                  hkActivityTypeRaw: $0.healthKitActivityType,
                                  logName: $0.name,
                                  kind: "exercise",
                                  sourceID: $0.id.uuidString)
                }
            }
            items += pd.voiceActivityIDs.compactMap { id in
                voices.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "waveform",
                                  isCompleted: completedNames.contains("Trainer – \($0.name)"),
                                  hkActivityTypeRaw: $0.healthKitActivityType,
                                  logName: "Trainer – \($0.name)",
                                  kind: "voice",
                                  sourceID: $0.id.uuidString)
                }
            }
            items += pd.timerIDs.compactMap { id in
                timers.first { $0.id == id }.map { c in
                    let displayName = c.name.isEmpty ? c.type.rawValue : c.name
                    return WidgetPlanItem(name: displayName, icon: c.type.iconName,
                                         isCompleted: completedNames.contains("\(c.type.rawValue) – \(displayName)"),
                                         hkActivityTypeRaw: c.healthKitActivityType,
                                         logName: "\(c.type.rawValue) – \(displayName)",
                                         kind: "timer",
                                         sourceID: c.id.uuidString)
                }
            }
            snapshots.append(WidgetPlanSnapshot(planName: plan.name, date: date, items: items, isRestDay: false, note: trimmedNote.isEmpty ? nil : trimmedNote))
        }
        writeMultiDaySnapshots(snapshots)
        WatchConnectivityReceiver.shared.sendPlanUpdate(multidaySnapshots: snapshots)
    }

    /// Writes today's total workout-log count into the App Group so the
    /// Watch's Library complication can show "N done" without needing to
    /// decode WorkoutLogs in the widget extension. Counts everything the
    /// user logged today across all kinds — workouts, exercises, timers,
    /// voice trainers — so the number can exceed the plan's planned-item
    /// count when the user does extra activities.
    func refreshTodayLogCount() {
        let wDefaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard
        let logs = (wDefaults.data(forKey: "workout_logs").flatMap { try? JSONDecoder().decode([WorkoutLog].self, from: $0) }) ?? []
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let count = logs.reduce(into: 0) { acc, log in
            if cal.isDate(log.completedAt, inSameDayAs: today) { acc += 1 }
        }
        writeTodayLogCount(count)
        // The watch widget extension reads from the watch device's App Group,
        // not the iPhone's, so a local write isn't enough — push the value
        // across so the Library complication can render it.
        WatchConnectivityReceiver.shared.sendTodayLogCountUpdate(count: count)
    }

    /// Projects the full library (workouts/exercises/timers/voice trainers) +
    /// recents into a flat snapshot the Watch can browse without decoding the
    /// full model graph. Independent of `activePlan` — runs even when the user
    /// has no plan configured, because Library browsing on the wrist should
    /// always work. Internal so the source state singletons (WorkoutsState,
    /// ExercisesState, TimerState, VoiceTrainerState) can call it directly when
    /// their data changes, without rebuilding today's plan snapshot too.
    func refreshWatchLibrary() {
        let wDefaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard
        let workouts  = (wDefaults.data(forKey: "workouts_data").flatMap  { try? JSONDecoder().decode([Workout].self,           from: $0) }) ?? []
        let exercises = (wDefaults.data(forKey: "exercises_data").flatMap { try? JSONDecoder().decode([Exercise].self,          from: $0) }) ?? []
        let voices    = (wDefaults.data(forKey: "VoiceTrainerConfigs").flatMap { try? JSONDecoder().decode([VoiceTrainerConfig].self, from: $0) }) ?? []
        let timers    = (wDefaults.data(forKey: "timer_configs").flatMap  { try? JSONDecoder().decode([TimerConfig].self,        from: $0) }) ?? []
        let logs      = (wDefaults.data(forKey: "workout_logs").flatMap   { try? JSONDecoder().decode([WorkoutLog].self,         from: $0) }) ?? []

        // Workout favorites live in a separate Set<UUID> store, not the unused
        // `Workout.isFavorite` field — match WorkoutsState.favoriteWorkoutIDs.
        let workoutFavoriteIDs: Set<UUID> = {
            guard let data = wDefaults.data(forKey: "workouts_favorites"),
                  let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return [] }
            return Set(ids)
        }()

        let exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let blueprints: [String: WatchWorkoutBlueprint] = Dictionary(
            uniqueKeysWithValues: workouts.map { workout in
                (workout.id.uuidString, Self.buildBlueprint(for: workout, exercisesByID: exercisesByID))
            }
        )
        let workoutItems: [WatchLibraryItem] = workouts.map {
            WatchLibraryItem(
                id: $0.id.uuidString, kind: "workout",
                name: $0.name, icon: "dumbbell.fill",
                hkActivityTypeRaw: $0.healthKitActivityType,
                logName: $0.name,
                isFavorite: workoutFavoriteIDs.contains($0.id)
            )
        }
        let exerciseItems: [WatchLibraryItem] = exercises.map {
            WatchLibraryItem(
                id: $0.id.uuidString, kind: "exercise",
                name: $0.name, icon: "figure.strengthtraining.traditional",
                hkActivityTypeRaw: $0.healthKitActivityType,
                logName: $0.name,
                isFavorite: $0.isFavorite
            )
        }
        let timerItems: [WatchLibraryItem] = timers.map { c in
            let displayName = c.name.isEmpty ? c.type.rawValue : c.name
            return WatchLibraryItem(
                id: c.id.uuidString, kind: "timer",
                name: displayName, icon: c.type.iconName,
                hkActivityTypeRaw: c.healthKitActivityType,
                logName: "\(c.type.rawValue) – \(displayName)",
                isFavorite: c.isFavorite
            )
        }
        let voiceItems: [WatchLibraryItem] = voices.map {
            WatchLibraryItem(
                id: $0.id.uuidString, kind: "voice",
                name: $0.name, icon: "waveform",
                hkActivityTypeRaw: $0.healthKitActivityType,
                logName: "Trainer – \($0.name)",
                isFavorite: $0.isFavorite
            )
        }

        // Build the Recents list by matching log names back to library items.
        // Logs use the same `logName` convention the watch starts sessions with
        // ("Trainer – X", "Tabata – Y", plain workout/exercise names), so we
        // index every library item by logName and walk the logs newest-first.
        let itemsByLogName = Dictionary(
            (workoutItems + exerciseItems + timerItems + voiceItems)
                .map { ($0.logName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var recents: [WatchLibraryItem] = []
        var seenIDs = Set<String>()
        for log in logs.sorted(by: { $0.completedAt > $1.completedAt }) {
            guard let item = itemsByLogName[log.workoutName] else { continue }
            guard !seenIDs.contains(item.id) else { continue }
            seenIDs.insert(item.id)
            recents.append(item)
            if recents.count >= 8 { break }
        }

        // Project voice trainer configs the watch needs to run lines on the
        // wrist (text split into lines, round/rest/delay timings, warnings).
        let voiceConfigs: [String: WatchVoiceTrainerConfig] = Dictionary(
            uniqueKeysWithValues: voices.map { vc in
                let lines = vc.text
                    .split(separator: "\n")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                return (
                    vc.id.uuidString,
                    WatchVoiceTrainerConfig(
                        id: vc.id.uuidString,
                        name: vc.name,
                        lines: lines,
                        roundLength: vc.roundLength,
                        restLength: vc.restLength,
                        delayBetweenLines: vc.delayBetweenLines,
                        numberOfRounds: vc.numberOfRounds,
                        randomOrder: vc.randomOrder,
                        workoutStartWarning: vc.workoutStartWarning,
                        restEndWarning: vc.restEndWarning
                    )
                )
            }
        )

        // Project timer configs so the Watch's wrist-side runner can drive
        // phase-by-phase progression (warmup, work/rest rounds, AMRAP,
        // ladder, cooldown) instead of just counting up from zero.
        let timerConfigs: [String: WatchTimerConfig] = Dictionary(
            uniqueKeysWithValues: timers.map { tc in
                (
                    tc.id.uuidString,
                    WatchTimerConfig(
                        id: tc.id.uuidString,
                        name: tc.name,
                        type: tc.type.rawValue,
                        direction: tc.direction.rawValue,
                        duration: tc.duration,
                        restDuration: tc.restDuration,
                        rounds: tc.rounds,
                        warmupDuration: tc.warmupDuration,
                        cooldownDuration: tc.cooldownDuration,
                        ladderStep: tc.ladderStep,
                        ladderPeakRounds: tc.ladderPeakRounds
                    )
                )
            }
        )

        let library = WatchLibrarySnapshot(
            workouts: workoutItems,
            exercises: exerciseItems,
            timers: timerItems,
            voiceTrainers: voiceItems,
            workoutBlueprints: blueprints,
            recents: recents,
            voiceConfigs: voiceConfigs,
            timerConfigs: timerConfigs
        )
        writeWatchLibrarySnapshot(library)
        WatchConnectivityReceiver.shared.sendLibraryUpdate(library)
    }

    private func saveActiveID() {
        defaults.set(activePlanID?.uuidString, forKey: activeKey)
        CloudKitSyncEngine.shared.push(.trainingPlans)
    }

    /// Called by CloudKitSyncEngine after a remote pull updates UserDefaults.
    func reloadFromDefaults() {
        load()
    }

    // MARK: - Watch blueprint construction

    /// Projects a Workout into a flat `WatchWorkoutBlueprint` the watch can run
    /// without knowing about the full model graph. Loops and complexes are
    /// pre-expanded into per-round exercise instances; timed-set targets carry
    /// `timedSeconds`; loop timer modes (Tabata/EMOM/Interval) populate
    /// `timedSeconds` (work) and `restSecondsAfter` (rest) so the watch chains
    /// work→rest→next automatically. Explicit `.rest(RestItem)` items attach
    /// their duration to the previous exercise's last set so the watch shows
    /// a rest screen at the right point.
    static func buildBlueprint(for workout: Workout,
                               exercisesByID: [UUID: Exercise]) -> WatchWorkoutBlueprint {
        var projection: [WatchBlueprintExercise] = []
        var walkItems: [WatchBlueprintItem] = []
        let items = workout.items
        var i = 0
        while i < items.count {
            switch items[i] {
            case .rest(let r):
                Self.attachRest(seconds: r.duration, to: &projection)
                // Rest doesn't get its own walk-item; its duration is absorbed
                // into the prior item's last set via attachRest.
                i += 1
            case .exercise(let we):
                if let loopID = we.loopID {
                    let loop = workout.loops[loopID.uuidString]
                    let rounds = max(loop?.rounds ?? 1, 1)
                    let workOverride = (loop?.timerMode?.workSeconds ?? 0)
                    let timerRest = (loop?.timerMode?.restSeconds ?? 0)
                    // Collect all consecutive items (exercises + rests) sharing
                    // this loopID — explicit in-loop rests get applied each round.
                    let (loopItems, nextIndex) = Self.collectLoopItems(items: items, startIndex: i, loopID: loopID)
                    i = nextIndex
                    for r in 1...rounds {
                        for loopItem in loopItems {
                            switch loopItem {
                            case .exercise(let we2):
                                let ex = exercisesByID[we2.exerciseID]
                                let entry = WatchBlueprintExercise(
                                    id: "\(we2.id.uuidString)-r\(r)",
                                    exerciseID: we2.exerciseID.uuidString,
                                    name: ex?.name ?? "Exercise",
                                    icon: "figure.strengthtraining.traditional",
                                    predefinedSets: Self.makeWatchPredefinedSets(
                                        from: we2.predefinedSets,
                                        timedOverrideSeconds: workOverride > 0 ? workOverride : nil,
                                        loopRestSeconds: timerRest
                                    ),
                                    loopRound: r,
                                    loopTotalRounds: rounds
                                )
                                projection.append(entry)
                                walkItems.append(.exercise(entry))
                            case .rest(let r):
                                Self.attachRest(seconds: r.duration, to: &projection)
                                // attachRest mutates the last walkItem-exercise too
                                Self.attachRestToLastItem(seconds: r.duration, in: &walkItems)
                            }
                        }
                    }
                } else if let complexID = we.complexID {
                    let complexCfg = workout.complexes[complexID.uuidString]
                    let rounds = max(complexCfg?.rounds ?? 1, 1)
                    let interval = max(complexCfg?.intervalSeconds ?? 60, 1)
                    var complexExercises: [WorkoutExercise] = []
                    while i < items.count {
                        if case .exercise(let we2) = items[i], we2.complexID == complexID {
                            complexExercises.append(we2)
                            i += 1
                        } else {
                            break
                        }
                    }
                    // Legacy `exercises` projection — keep the per-round
                    // flat-expanded entries so older Watch builds still see
                    // something walkable.
                    for r in 1...rounds {
                        for we2 in complexExercises {
                            let ex = exercisesByID[we2.exerciseID]
                            projection.append(WatchBlueprintExercise(
                                id: "\(we2.id.uuidString)-cr\(r)",
                                exerciseID: we2.exerciseID.uuidString,
                                name: ex?.name ?? "Exercise",
                                icon: "figure.strengthtraining.traditional",
                                predefinedSets: Self.makeWatchPredefinedSets(from: we2.predefinedSets),
                                complexRound: r,
                                complexTotalRounds: rounds
                            ))
                        }
                    }
                    // New `items` projection — one `.complex` carrying every
                    // exercise once + the round/interval config. New runners
                    // use this to show all exercises on one screen.
                    let complexExerciseEntries: [WatchBlueprintExercise] = complexExercises.map { we2 in
                        let ex = exercisesByID[we2.exerciseID]
                        return WatchBlueprintExercise(
                            id: we2.id.uuidString,
                            exerciseID: we2.exerciseID.uuidString,
                            name: ex?.name ?? "Exercise",
                            icon: "figure.strengthtraining.traditional",
                            predefinedSets: Self.makeWatchPredefinedSets(from: we2.predefinedSets)
                        )
                    }
                    walkItems.append(.complex(WatchBlueprintComplex(
                        id: complexID.uuidString,
                        name: workout.name,
                        rounds: rounds,
                        intervalSeconds: interval,
                        exercises: complexExerciseEntries
                    )))
                } else {
                    let ex = exercisesByID[we.exerciseID]
                    let entry = WatchBlueprintExercise(
                        id: we.id.uuidString,
                        exerciseID: we.exerciseID.uuidString,
                        name: ex?.name ?? "Exercise",
                        icon: "figure.strengthtraining.traditional",
                        predefinedSets: Self.makeWatchPredefinedSets(from: we.predefinedSets)
                    )
                    projection.append(entry)
                    walkItems.append(.exercise(entry))
                    i += 1
                }
            }
        }
        return WatchWorkoutBlueprint(
            id: workout.id.uuidString,
            name: workout.name,
            hkActivityTypeRaw: workout.healthKitActivityType,
            exercises: projection,
            items: walkItems
        )
    }

    /// Companion to `attachRest` — mirrors the rest onto the corresponding
    /// `.exercise` entry inside `walkItems` so the new item-based runner sees
    /// the same restSecondsAfter the old flat-list runner would.
    private static func attachRestToLastItem(seconds: Int,
                                             in items: inout [WatchBlueprintItem]) {
        guard seconds > 0, !items.isEmpty else { return }
        guard case .exercise(let ex) = items.removeLast() else { return }
        guard !ex.predefinedSets.isEmpty else {
            items.append(.exercise(ex))
            return
        }
        var sets = ex.predefinedSets
        let lastSet = sets.removeLast()
        sets.append(WatchPredefinedSet(
            reps: lastSet.reps,
            weight: lastSet.weight,
            timedSeconds: lastSet.timedSeconds,
            restSecondsAfter: max(lastSet.restSecondsAfter, seconds)
        ))
        items.append(.exercise(WatchBlueprintExercise(
            id: ex.id,
            exerciseID: ex.exerciseID,
            name: ex.name,
            icon: ex.icon,
            predefinedSets: sets,
            loopRound: ex.loopRound,
            loopTotalRounds: ex.loopTotalRounds,
            complexRound: ex.complexRound,
            complexTotalRounds: ex.complexTotalRounds
        )))
    }

    /// Walks forward from `startIndex` collecting consecutive items (exercises
    /// or rests) that belong to `loopID`. Stops at the first item that doesn't
    /// belong. Returns the collected items + the index after the last consumed.
    private static func collectLoopItems(items: [WorkoutItem],
                                         startIndex: Int,
                                         loopID: UUID) -> (loopItems: [WorkoutItem], endIndex: Int) {
        var result: [WorkoutItem] = []
        var i = startIndex
        while i < items.count {
            switch items[i] {
            case .exercise(let we) where we.loopID == loopID:
                result.append(items[i])
                i += 1
            case .rest(let r) where r.loopID == loopID:
                result.append(items[i])
                i += 1
            default:
                return (result, i)
            }
        }
        return (result, i)
    }

    /// Modifies the last appended exercise's last predefined set to have at
    /// least `seconds` of rest after. Picks max(existing, new) so a loop's
    /// per-set timer rest is preserved even when a larger explicit rest also
    /// applies to the same boundary.
    private static func attachRest(seconds: Int, to projection: inout [WatchBlueprintExercise]) {
        guard seconds > 0, !projection.isEmpty else { return }
        let last = projection.removeLast()
        guard !last.predefinedSets.isEmpty else {
            projection.append(last)
            return
        }
        var sets = last.predefinedSets
        let lastSet = sets.removeLast()
        sets.append(WatchPredefinedSet(
            reps: lastSet.reps,
            weight: lastSet.weight,
            timedSeconds: lastSet.timedSeconds,
            restSecondsAfter: max(lastSet.restSecondsAfter, seconds)
        ))
        projection.append(WatchBlueprintExercise(
            id: last.id,
            exerciseID: last.exerciseID,
            name: last.name,
            icon: last.icon,
            predefinedSets: sets,
            loopRound: last.loopRound,
            loopTotalRounds: last.loopTotalRounds,
            complexRound: last.complexRound,
            complexTotalRounds: last.complexTotalRounds
        ))
    }

    /// Converts iPhone `PredefinedSet`s into watch-side ones. When the loop
    /// containing this exercise has a Tabata/EMOM/Interval timer mode,
    /// `timedOverrideSeconds` is passed so every set runs the loop's work
    /// duration as a countdown; `loopRestSeconds` populates the auto-rest
    /// after each work set.
    private static func makeWatchPredefinedSets(from sets: [PredefinedSet],
                                                timedOverrideSeconds: Int? = nil,
                                                loopRestSeconds: Int = 0) -> [WatchPredefinedSet] {
        sets.map { ps in
            if let override = timedOverrideSeconds, override > 0 {
                return WatchPredefinedSet(
                    reps: 0, weight: ps.weight,
                    timedSeconds: override,
                    restSecondsAfter: loopRestSeconds
                )
            }
            switch ps.target {
            case .reps(let n):
                return WatchPredefinedSet(
                    reps: n, weight: ps.weight,
                    timedSeconds: 0,
                    restSecondsAfter: loopRestSeconds
                )
            case .timed(let s):
                return WatchPredefinedSet(
                    reps: 0, weight: ps.weight,
                    timedSeconds: s,
                    restSecondsAfter: loopRestSeconds
                )
            }
        }
    }
}
