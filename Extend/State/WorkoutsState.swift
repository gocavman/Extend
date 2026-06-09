////
////  WorkoutsState.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Observation
import Foundation

// MARK: - Workout Package (self-contained export/import format)

/// A portable bundle containing workouts plus all referenced exercises, equipment,
/// and muscle groups. UUIDs inside the file are only used for internal consistency
/// within the package; on import everything is matched by name so the file works
/// across different installs and users.
public struct WorkoutPackage: Codable {
    public var workouts: [Workout]
    public var exercises: [Exercise]
    public var equipment: [Equipment]
    public var muscleGroups: [MuscleGroup]
}

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

@Observable
public final class WorkoutsState {
    public static let shared = WorkoutsState()

    @ObservationIgnored private let storageKey = "workouts_data"
    @ObservationIgnored private let favoritesKey = "workouts_favorites"

    public var workouts: [Workout] = []
    public var favoriteWorkoutIDs: Set<UUID> = []

    /// Set by the dashboard to deep-link directly into a specific workout's start screen
    public var pendingLaunchID: UUID? = nil

    /// Set by the dashboard to deep-link directly into a specific workout's stats screen
    public var pendingStatsID: UUID? = nil

    /// Set by the dashboard to deep-link directly into a specific workout's history screen
    public var pendingHistoryID: UUID? = nil

    private init() {
        loadWorkouts()
        loadFavorites()
    }

    public func toggleFavorite(id: UUID) {
        if favoriteWorkoutIDs.contains(id) {
            favoriteWorkoutIDs.remove(id)
        } else {
            favoriteWorkoutIDs.insert(id)
        }
        saveFavorites()
    }

    public func isFavorite(_ id: UUID) -> Bool {
        favoriteWorkoutIDs.contains(id)
    }

    public var favoriteWorkouts: [Workout] {
        workouts.filter { favoriteWorkoutIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func resetFavorites() {
        favoriteWorkoutIDs = []
        saveFavorites()
    }

    public func addWorkout(_ workout: Workout) {
        workouts.append(workout)
        saveWorkouts()
    }

    public func updateWorkout(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
            saveWorkouts()
        }
    }

    public func removeWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
        saveWorkouts()
    }

    public func cloneWorkout(_ workout: Workout) {
        // Remap loopIDs and complexIDs so the cloned workout has fresh but internally consistent groupings.
        var loopIDMap: [UUID: UUID] = [:]
        var complexIDMap: [UUID: UUID] = [:]
        let clonedItems: [WorkoutItem] = workout.items.map { item in
            switch item {
            case .exercise(let ex):
                let newLoopID: UUID? = ex.loopID.map { old in
                    if let mapped = loopIDMap[old] { return mapped }
                    let fresh = UUID()
                    loopIDMap[old] = fresh
                    return fresh
                }
                let newComplexID: UUID? = ex.complexID.map { old in
                    if let mapped = complexIDMap[old] { return mapped }
                    let fresh = UUID()
                    complexIDMap[old] = fresh
                    return fresh
                }
                return .exercise(WorkoutExercise(
                    exerciseID: ex.exerciseID,
                    loopID: newLoopID,
                    complexID: newComplexID,
                    predefinedSets: ex.predefinedSets.map { PredefinedSet(target: $0.target, weight: $0.weight) },
                    defaultEquipmentIDs: ex.defaultEquipmentIDs
                ))
            case .rest(let r):
                return .rest(RestItem(duration: r.duration))
            }
        }
        // Remap loop entries using the same UUID map built above
        var clonedLoops: [String: WorkoutLoop] = [:]
        for (oldKey, loop) in workout.loops {
            let oldUUID = UUID(uuidString: oldKey) ?? UUID()
            let newUUID = loopIDMap[oldUUID] ?? UUID()
            clonedLoops[newUUID.uuidString] = WorkoutLoop(id: newUUID, rounds: loop.rounds, timerMode: loop.timerMode)
        }
        // Remap complex entries using the same UUID map built above
        var clonedComplexes: [String: WorkoutComplex] = [:]
        for (oldKey, cx) in workout.complexes {
            guard let oldUUID = UUID(uuidString: oldKey) else { continue }
            let newUUID = complexIDMap[oldUUID] ?? UUID()
            clonedComplexes[newUUID.uuidString] = WorkoutComplex(id: newUUID, rounds: cx.rounds, intervalSeconds: cx.intervalSeconds, autoAdvance: cx.autoAdvance, roundCountdown: cx.roundCountdown, timerStyle: cx.timerStyle)
        }
        let cloned = Workout(
            id: UUID(),
            name: "\(workout.name) Copy",
            notes: workout.notes,
            items: clonedItems,
            loops: clonedLoops,
            complexes: clonedComplexes,
            warmupSeconds: workout.warmupSeconds,
            cooldownSeconds: workout.cooldownSeconds
        )
        workouts.append(cloned)
        saveWorkouts()
    }

    public func resetWorkouts() {
        workouts = Self.createDefaultWorkouts()
        saveWorkouts()
    }

    // MARK: - Default Workouts

    private static func createDefaultWorkouts() -> [Workout] {
        // Stable exercise UUIDs (must match ExercisesState defaults)
        let cleanID    = UUID(uuidString: "C59510E0-3885-4D18-B80F-C21AFBE779BD")!
        let pressID    = UUID(uuidString: "82527C8B-1AAF-4702-90DF-F8897614A106")!
        let squatID    = UUID(uuidString: "D95A4C3A-B832-463C-BCA7-4C47771CE2C9")!
        let kettlebell = UUID(uuidString: "00000107-0000-0000-0000-000000000000")!

        func reps(_ n: Int, weight: Double) -> PredefinedSet {
            PredefinedSet(target: .reps(n), weight: weight)
        }

        // ── ABC - Double Kettlebell ───────────────────────────────────────
        // Complex: 30 rounds × 60s, auto-advance, round countdown, ring style
        let dblComplexID = UUID(uuidString: "EEBFB2C1-74F9-4AD3-891F-AFBF619C2480")!
        let dblComplex   = WorkoutComplex(
            id: dblComplexID,
            rounds: 30,
            intervalSeconds: 60,
            autoAdvance: true,
            roundCountdown: true,
            timerStyle: .ring
        )
        let dblItems: [WorkoutItem] = [
            .exercise(WorkoutExercise(
                id: UUID(uuidString: "B6648804-9BC7-4D6F-8138-761F17073753")!,
                exerciseID: cleanID,
                complexID: dblComplexID,
                predefinedSets: (0..<30).map { _ in reps(2, weight: 40) },
                defaultEquipmentIDs: [kettlebell]
            )),
            .exercise(WorkoutExercise(
                id: UUID(uuidString: "F1000001-0000-0000-0000-000000000001")!,
                exerciseID: pressID,
                complexID: dblComplexID,
                predefinedSets: (0..<30).map { _ in reps(1, weight: 40) },
                defaultEquipmentIDs: [kettlebell]
            )),
            .exercise(WorkoutExercise(
                id: UUID(uuidString: "F1000001-0000-0000-0000-000000000002")!,
                exerciseID: squatID,
                complexID: dblComplexID,
                predefinedSets: (0..<30).map { _ in reps(3, weight: 40) },
                defaultEquipmentIDs: [kettlebell]
            )),
        ]
        let doubleKB = Workout(
            id: UUID(uuidString: "193636A4-130A-4389-89AF-0D3226B5568A")!,
            name: "ABC - Double Kettlebell",
            notes: "1. 2 cleans \n2. 1 press \n3. 3 squats",
            items: dblItems,
            healthKitActivityType: 73,
            loops: [:],
            complexes: [dblComplexID.uuidString: dblComplex],
            warmupSeconds: 15,
            cooldownSeconds: 15,
            showNotes: false
        )

        // ── ABC - Single Kettlebell ───────────────────────────────────────
        // Complex: 30 rounds × 90s, auto-advance, round countdown, bar style
        let sglComplexID = UUID(uuidString: "402AFA25-45F9-45DF-AEFE-C83FCF4FB5B0")!
        let sglComplex   = WorkoutComplex(
            id: sglComplexID,
            rounds: 30,
            intervalSeconds: 90,
            autoAdvance: true,
            roundCountdown: true,
            timerStyle: .bar
        )
        let sglItems: [WorkoutItem] = [
            .exercise(WorkoutExercise(
                id: UUID(uuidString: "F1000002-0000-0000-0000-000000000001")!,
                exerciseID: cleanID,
                complexID: sglComplexID,
                predefinedSets: (0..<30).map { _ in reps(2, weight: 40) },
                defaultEquipmentIDs: [kettlebell]
            )),
            .exercise(WorkoutExercise(
                id: UUID(uuidString: "F1000002-0000-0000-0000-000000000002")!,
                exerciseID: pressID,
                complexID: sglComplexID,
                predefinedSets: (0..<30).map { _ in reps(2, weight: 40) },
                defaultEquipmentIDs: [kettlebell]
            )),
            .exercise(WorkoutExercise(
                id: UUID(uuidString: "F1000002-0000-0000-0000-000000000003")!,
                exerciseID: squatID,
                complexID: sglComplexID,
                predefinedSets: (0..<30).map { _ in reps(2, weight: 40) },
                defaultEquipmentIDs: [kettlebell]
            )),
        ]
        let singleKB = Workout(
            id: UUID(uuidString: "1EBE4E9D-C045-41AB-B556-7B433557DD1D")!,
            name: "ABC - Single Kettlebell",
            notes: "1. Left arm clean & press \n2. Right arm clean & press immediately going to: \n3. 2 squats with kb on right. \n4. Switch arms",
            items: sglItems,
            healthKitActivityType: nil,
            loops: [:],
            complexes: [sglComplexID.uuidString: sglComplex],
            warmupSeconds: 15,
            cooldownSeconds: 15,
            showNotes: true
        )

        return [doubleKB, singleKB]
    }

    /// Builds a self-contained WorkoutPackage containing the selected workouts plus
    /// every exercise, equipment item, and muscle group they reference.
    public func exportData(
        for workoutsToExport: [Workout],
        exercisesState: ExercisesState,
        equipmentState: EquipmentState,
        muscleGroupsState: MuscleGroupsState
    ) -> Data? {
        // Collect all exerciseIDs referenced by the selected workouts
        let exerciseIDs = Set(workoutsToExport.flatMap { w in
            w.items.compactMap { item -> UUID? in
                if case .exercise(let we) = item { return we.exerciseID }
                return nil
            }
        })
        let referencedExercises = exercisesState.exercises.filter { exerciseIDs.contains($0.id) }

        // Collect all equipment and muscle group IDs referenced by those exercises
        let equipmentIDs = Set(referencedExercises.flatMap { $0.equipmentIDs })
        let muscleIDs    = Set(referencedExercises.flatMap { $0.primaryMuscleGroupIDs + $0.secondaryMuscleGroupIDs })

        let referencedEquipment     = equipmentState.items.filter { equipmentIDs.contains($0.id) }
        let referencedMuscleGroups  = muscleGroupsState.groups.filter { muscleIDs.contains($0.id) }

        let package = WorkoutPackage(
            workouts: workoutsToExport,
            exercises: referencedExercises,
            equipment: referencedEquipment,
            muscleGroups: referencedMuscleGroups
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(package)
    }

    /// Imports workouts from a WorkoutPackage JSON file.
    ///
    /// Resolution strategy (name-based, UUID-agnostic):
    /// 1. Muscle groups — match by name; create if missing.
    /// 2. Equipment     — match by name; create if missing.
    /// 3. Exercises     — match by name; create if missing (remapping muscle/equipment IDs).
    /// 4. Workouts      — remap exerciseIDs; rename on name collision.
    ///
    /// Returns the number of workouts successfully imported.
    @discardableResult
    public func importWorkouts(
        from data: Data,
        exercisesState: ExercisesState,
        equipmentState: EquipmentState,
        muscleGroupsState: MuscleGroupsState
    ) throws -> Int {
        // Support both the new package format and the old bare [Workout] format
        let package: WorkoutPackage
        if let p = try? JSONDecoder().decode(WorkoutPackage.self, from: data) {
            package = p
        } else {
            // Legacy: bare array of workouts with no embedded dependencies
            let bare = try JSONDecoder().decode([Workout].self, from: data)
            package = WorkoutPackage(workouts: bare, exercises: [], equipment: [], muscleGroups: [])
        }

        // ── 1. Resolve muscle groups (file UUID → local UUID) ────────────
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

        // ── 2. Resolve equipment (file UUID → local UUID) ────────────────
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

        // ── 3. Resolve exercises (file UUID → local UUID) ────────────────
        var exerciseIDMap: [UUID: UUID] = [:]
        for ex in package.exercises {
            if let existing = exercisesState.exercises.first(where: {
                $0.name.localizedCaseInsensitiveCompare(ex.name) == .orderedSame
            }) {
                exerciseIDMap[ex.id] = existing.id
            } else {
                // Remap the exercise's muscle/equipment IDs to local IDs
                let remappedPrimary   = ex.primaryMuscleGroupIDs.map   { muscleIDMap[$0] ?? $0 }
                let remappedSecondary = ex.secondaryMuscleGroupIDs.map { muscleIDMap[$0] ?? $0 }
                let remappedEquipment = ex.equipmentIDs.map            { equipIDMap[$0]  ?? $0 }
                let remappedDefaults  = ex.defaultEquipmentIDs.map     { equipIDMap[$0]  ?? $0 }
                let fresh = Exercise(
                    name: ex.name,
                    notes: ex.notes,
                    primaryMuscleGroupIDs: remappedPrimary,
                    secondaryMuscleGroupIDs: remappedSecondary,
                    equipmentIDs: remappedEquipment,
                    defaultEquipmentIDs: remappedDefaults,
                    healthKitActivityType: ex.healthKitActivityType
                )
                exercisesState.addExercise(fresh)
                exerciseIDMap[ex.id] = fresh.id
            }
        }

        // ── 4. Import workouts, remapping exerciseIDs ─────────────────────
        var count = 0
        for original in package.workouts {
            let remappedItems: [WorkoutItem] = original.items.map { item in
                guard case .exercise(let we) = item else { return item }
                let resolvedExerciseID = exerciseIDMap[we.exerciseID] ?? we.exerciseID
                let remappedEquipment  = we.defaultEquipmentIDs.map { equipIDMap[$0] ?? $0 }
                return .exercise(WorkoutExercise(
                    id: UUID(),
                    exerciseID: resolvedExerciseID,
                    loopID: we.loopID,
                    complexID: we.complexID,
                    predefinedSets: we.predefinedSets,
                    defaultEquipmentIDs: remappedEquipment
                ))
            }
            let workout = Workout(
                id: UUID(),
                name: uniqueName(for: original.name),
                notes: original.notes,
                items: remappedItems,
                healthKitActivityType: original.healthKitActivityType,
                loops: original.loops,
                complexes: original.complexes,
                warmupSeconds: original.warmupSeconds,
                cooldownSeconds: original.cooldownSeconds,
                showNotes: original.showNotes
            )
            workouts.append(workout)
            count += 1
        }
        saveWorkouts()
        return count
    }

    /// Returns a name that doesn't conflict with any existing workout name,
    /// appending "(2)", "(3)", etc. as needed.
    private func uniqueName(for name: String) -> String {
        let existing = Set(workouts.map { $0.name })
        guard existing.contains(name) else { return name }
        var n = 2
        while existing.contains("\(name) (\(n))") { n += 1 }
        return "\(name) (\(n))"
    }

    private func loadWorkouts() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = decoded
        } else {
            // Fresh install — seed default workouts
            workouts = Self.createDefaultWorkouts()
            saveWorkouts()
        }
    }

    private func saveWorkouts() {
        if let encoded = try? JSONEncoder().encode(workouts) {
            defaults.set(encoded, forKey: storageKey)
        }
    }

    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(Array(favoriteWorkoutIDs)) {
            defaults.set(encoded, forKey: favoritesKey)
        }
    }

    private func loadFavorites() {
        if let data = defaults.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
            favoriteWorkoutIDs = Set(decoded)
        }
    }
}
