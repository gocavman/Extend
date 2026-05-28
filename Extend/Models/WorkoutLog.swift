////
////  WorkoutLog.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/13/26.
////

import Foundation

/// Represents a completed workout that has been logged
public struct WorkoutLog: Identifiable, Codable, Hashable {
    public let id: UUID
    public var workoutName: String
    public var completedAt: Date
    public var exercises: [LoggedExercise]
    public var restPeriods: [LoggedRest]
    public var notes: String
    public var duration: TimeInterval // in seconds
    /// UUID of the matching HKWorkout in Apple Health (nil if not yet exported)
    public var healthKitUUID: UUID?
    /// Raw value of HKWorkoutActivityType used when exporting to Apple Health (nil → .other)
    public var healthKitActivityTypeRaw: UInt?

    public init(
        id: UUID = UUID(),
        workoutName: String,
        completedAt: Date = Date(),
        exercises: [LoggedExercise] = [],
        restPeriods: [LoggedRest] = [],
        notes: String = "",
        duration: TimeInterval = 0,
        healthKitUUID: UUID? = nil,
        healthKitActivityTypeRaw: UInt? = nil
    ) {
        self.id = id
        self.workoutName = workoutName
        self.completedAt = completedAt
        self.exercises = exercises
        self.restPeriods = restPeriods
        self.notes = notes
        self.duration = duration
        self.healthKitUUID = healthKitUUID
        self.healthKitActivityTypeRaw = healthKitActivityTypeRaw
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workoutName = try c.decode(String.self, forKey: .workoutName)
        completedAt = try c.decode(Date.self, forKey: .completedAt)
        exercises = try c.decode([LoggedExercise].self, forKey: .exercises)
        restPeriods = (try? c.decodeIfPresent([LoggedRest].self, forKey: .restPeriods)) ?? []
        notes = try c.decode(String.self, forKey: .notes)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        healthKitUUID = try? c.decodeIfPresent(UUID.self, forKey: .healthKitUUID)
        healthKitActivityTypeRaw = try? c.decodeIfPresent(UInt.self, forKey: .healthKitActivityTypeRaw)
    }
}

/// Represents a single exercise within a logged workout
public struct LoggedExercise: Identifiable, Codable, Hashable {
    public let id: UUID
    public let exerciseID: UUID
    public var exerciseName: String
    public var sets: [LoggedSet]
    public var notes: String
    /// Seconds the stopwatch ran for this exercise
    public var activeSeconds: Int
    /// Equipment IDs the user indicated they actually used for this exercise session
    public var usedEquipmentIDs: [UUID]
    /// Position of this item in the original workout's item list (for ordering in the log view)
    public var orderIndex: Int
    /// Loop group ID — exercises sharing the same non-nil loopID were in a superset/circuit
    public var loopID: UUID?
    /// Complex group ID — exercises sharing the same non-nil complexID were in a complex
    public var complexID: UUID?

    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseName: String,
        sets: [LoggedSet] = [],
        notes: String = "",
        activeSeconds: Int = 0,
        usedEquipmentIDs: [UUID] = [],
        orderIndex: Int = 0,
        loopID: UUID? = nil,
        complexID: UUID? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sets = sets
        self.notes = notes
        self.activeSeconds = activeSeconds
        self.usedEquipmentIDs = usedEquipmentIDs
        self.orderIndex = orderIndex
        self.loopID = loopID
        self.complexID = complexID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        exerciseID = try c.decode(UUID.self, forKey: .exerciseID)
        exerciseName = try c.decode(String.self, forKey: .exerciseName)
        sets = try c.decode([LoggedSet].self, forKey: .sets)
        notes = try c.decode(String.self, forKey: .notes)
        activeSeconds = (try? c.decodeIfPresent(Int.self, forKey: .activeSeconds)) ?? 0
        usedEquipmentIDs = (try? c.decodeIfPresent([UUID].self, forKey: .usedEquipmentIDs)) ?? []
        orderIndex = (try? c.decodeIfPresent(Int.self, forKey: .orderIndex)) ?? 0
        loopID = try? c.decodeIfPresent(UUID.self, forKey: .loopID)
        complexID = try? c.decodeIfPresent(UUID.self, forKey: .complexID)
    }
}

/// Represents a single set within a logged exercise
public struct LoggedSet: Identifiable, Codable, Hashable {
    public let id: UUID
    public var reps: Int
    public var weight: Double
    /// Seconds elapsed on the per-set timed countdown (0 if not a timed set)
    public var timedSeconds: Int

    public init(id: UUID = UUID(), reps: Int, weight: Double, timedSeconds: Int = 0) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.timedSeconds = timedSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reps = try c.decode(Int.self, forKey: .reps)
        weight = try c.decode(Double.self, forKey: .weight)
        timedSeconds = (try? c.decodeIfPresent(Int.self, forKey: .timedSeconds)) ?? 0
    }
}

// MARK: - Set Run Grouping

/// A run of consecutive identical sets, used to compact log display.
public struct LoggedSetRun {
    /// 1-based index of the first set in this run.
    public let startIndex: Int
    /// 1-based index of the last set in this run.
    public let endIndex: Int
    /// The representative set value for the run.
    public let set: LoggedSet

    /// "Set N" or "Sets N–M"
    public var label: String {
        startIndex == endIndex ? "Set \(startIndex)" : "Sets \(startIndex)–\(endIndex)"
    }
}

public extension Array where Element == LoggedSet {
    /// Groups consecutive sets with identical reps, weight, and timedSeconds into runs.
    func groupedRuns() -> [LoggedSetRun] {
        var result: [LoggedSetRun] = []
        for (i, set) in enumerated() {
            let oneBasedIndex = i + 1
            if let last = result.last,
               last.set.reps == set.reps,
               last.set.weight == set.weight,
               last.set.timedSeconds == set.timedSeconds {
                result[result.count - 1] = LoggedSetRun(startIndex: last.startIndex, endIndex: oneBasedIndex, set: last.set)
            } else {
                result.append(LoggedSetRun(startIndex: oneBasedIndex, endIndex: oneBasedIndex, set: set))
            }
        }
        return result
    }
}

/// A rest period that was part of a logged workout
public struct LoggedRest: Identifiable, Codable, Hashable {
    public let id: UUID
    /// The configured rest duration in seconds
    public var configuredDuration: Int
    /// How long the user actually rested (timer value when they moved on)
    public var actualDuration: Int
    /// Position of this item in the original workout's item list (for ordering in the log view)
    public var orderIndex: Int

    public init(id: UUID = UUID(), configuredDuration: Int, actualDuration: Int, orderIndex: Int = 0) {
        self.id = id
        self.configuredDuration = configuredDuration
        self.actualDuration = actualDuration
        self.orderIndex = orderIndex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        configuredDuration = try c.decode(Int.self, forKey: .configuredDuration)
        actualDuration = try c.decode(Int.self, forKey: .actualDuration)
        orderIndex = (try? c.decodeIfPresent(Int.self, forKey: .orderIndex)) ?? 0
    }
}

/// A freeform journal/note entry attached to a calendar date
public struct JournalEntry: Identifiable, Codable, Hashable {
    public let id: UUID
    public var date: Date
    public var title: String
    public var body: String

    public init(id: UUID = UUID(), date: Date = Date(), title: String = "", body: String = "") {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
    }
}
