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
        guard let plan = activePlan else {
            writeWidgetSnapshot(planName: nil, items: [])
            return
        }
        let pd = planDay(for: Date())
        guard let pd else {
            writeWidgetSnapshot(planName: plan.name, items: [])
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
                                  isCompleted: completedNames.contains($0.name))
                }
            }
        }
        // Exercises
        if let data = wDefaults.data(forKey: "exercises_data"),
           let exercises = try? JSONDecoder().decode([Exercise].self, from: data) {
            items += pd.exerciseIDs.compactMap { id in
                exercises.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "figure.strengthtraining.traditional",
                                  isCompleted: completedNames.contains($0.name))
                }
            }
        }
        // Voice trainers
        if let data = wDefaults.data(forKey: "VoiceTrainerConfigs"),
           let configs = try? JSONDecoder().decode([VoiceTrainerConfig].self, from: data) {
            items += pd.voiceActivityIDs.compactMap { id in
                configs.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "waveform",
                                  isCompleted: completedNames.contains("Trainer – \($0.name)"))
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
                                         isCompleted: completedNames.contains("\(c.type.rawValue) – \(displayName)"))
                }
            }
        }

        writeWidgetSnapshot(planName: plan.name, items: items)

        // Also write a ±7-day window so the Watch app can browse nearby days.
        refreshMultiDaySnapshots()
    }

    /// Builds plan snapshots for today ±7 days and writes them to the App Group
    /// under the "widget_plan_multiday" key for the Watch app's day-browsing view.
    private func refreshMultiDaySnapshots() {
        guard let plan = activePlan else {
            writeMultiDaySnapshots([])
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

            if pd.isEmpty {
                snapshots.append(WidgetPlanSnapshot(planName: plan.name, date: date, items: [], isRestDay: true))
                continue
            }

            // Build completed set for this date
            let dayLogs = logs.filter { cal.isDate($0.completedAt, inSameDayAs: date) }
            let completedNames = Set(dayLogs.map { $0.workoutName })

            var items: [WidgetPlanItem] = []
            items += pd.workoutIDs.compactMap { id in
                workouts.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "dumbbell.fill",
                                  isCompleted: completedNames.contains($0.name))
                }
            }
            items += pd.exerciseIDs.compactMap { id in
                exercises.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "figure.strengthtraining.traditional",
                                  isCompleted: completedNames.contains($0.name))
                }
            }
            items += pd.voiceActivityIDs.compactMap { id in
                voices.first { $0.id == id }.map {
                    WidgetPlanItem(name: $0.name, icon: "waveform",
                                  isCompleted: completedNames.contains("Trainer – \($0.name)"))
                }
            }
            items += pd.timerIDs.compactMap { id in
                timers.first { $0.id == id }.map { c in
                    let displayName = c.name.isEmpty ? c.type.rawValue : c.name
                    return WidgetPlanItem(name: displayName, icon: c.type.iconName,
                                         isCompleted: completedNames.contains("\(c.type.rawValue) – \(displayName)"))
                }
            }
            snapshots.append(WidgetPlanSnapshot(planName: plan.name, date: date, items: items, isRestDay: false))
        }
        writeMultiDaySnapshots(snapshots)
        WatchConnectivityReceiver.shared.sendPlanUpdate(multidaySnapshots: snapshots)
    }

    private func saveActiveID() {
        defaults.set(activePlanID?.uuidString, forKey: activeKey)
        CloudKitSyncEngine.shared.push(.trainingPlans)
    }

    /// Called by CloudKitSyncEngine after a remote pull updates UserDefaults.
    func reloadFromDefaults() {
        load()
    }
}
