import Foundation

// MARK: - Training Plan Model

struct TrainingPlan: Identifiable, Codable {
    let id: UUID
    var name: String
    var startDate: Date
    /// 0 = repeating weekly template forever; >0 = fixed number of weeks
    var weeks: Int
    /// The default weekly template. 7 entries, index 0 = Sunday … 6 = Saturday.
    var template: [PlanDay]
    /// Per-week overrides keyed by week index (0-based). Only populated for fixed plans.
    /// Days not overridden fall back to the template.
    var weekOverrides: [String: [PlanDay]]  // String keys for Codable compatibility

    init(id: UUID = UUID(), name: String, startDate: Date = Date(), weeks: Int = 0) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.weeks = weeks
        self.template = (0..<7).map { PlanDay(dayOfWeek: $0) }
        self.weekOverrides = [:]
    }

    /// Returns the PlanDay for a given date.
    /// Fixed plans use per-week data; repeating plans use week 0 data.
    func planDay(for date: Date) -> PlanDay {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) - 1  // 0=Sun..6=Sat

        if weeks > 0 {
            // Fixed plan: look up this date's week index
            let startOfStart = calendar.startOfDay(for: startDate)
            let startOfDate = calendar.startOfDay(for: date)
            let dayDiff = calendar.dateComponents([.day], from: startOfStart, to: startOfDate).day ?? 0
            let weekIndex = dayDiff / 7
            let key = String(weekIndex)
            if let overrideDays = weekOverrides[key],
               let day = overrideDays.first(where: { $0.dayOfWeek == weekday }) {
                return day
            }
            return PlanDay(dayOfWeek: weekday)
        } else {
            // Repeating plan: use week 0 as the single template
            if let days = weekOverrides["0"],
               let day = days.first(where: { $0.dayOfWeek == weekday }) {
                return day
            }
            return PlanDay(dayOfWeek: weekday)
        }
    }

    /// Returns true only if `date` falls within this plan's active date range.
    func isActive(on date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        let startOfDate = calendar.startOfDay(for: date)
        guard startOfDate >= startOfStart else { return false }
        if weeks == 0 { return true }  // repeating forever
        let dayDiff = calendar.dateComponents([.day], from: startOfStart, to: startOfDate).day ?? 0
        return dayDiff / 7 < weeks
    }

    /// Set a day for a specific week index (0-based). For repeating plans pass weekIndex 0.
    mutating func setDay(_ day: PlanDay, forWeek weekIndex: Int) {
        let key = String(weekIndex)
        var days = weekOverrides[key] ?? []
        if let idx = days.firstIndex(where: { $0.dayOfWeek == day.dayOfWeek }) {
            if day.isEmpty {
                days.remove(at: idx)
            } else {
                days[idx] = day
            }
        } else if !day.isEmpty {
            days.append(day)
        }
        if days.isEmpty {
            weekOverrides.removeValue(forKey: key)
        } else {
            weekOverrides[key] = days
        }
    }

    /// Copy a day to every week in a fixed plan (weeks > 0).
    mutating func applyToAllWeeks(_ day: PlanDay) {
        guard weeks > 0 else { return }
        for weekIndex in 0..<weeks {
            setDay(day, forWeek: weekIndex)
        }
    }
}

// MARK: - Plan Day

struct PlanDay: Identifiable, Codable {
    let id: UUID
    var dayOfWeek: Int          // 0 = Sunday … 6 = Saturday
    var workoutIDs: [UUID]         // ordered list of workouts for this day
    var exerciseIDs: [UUID]        // individual exercises
    var voiceActivityIDs: [UUID]   // voice trainer configurations
    var timerIDs: [UUID]           // timer configurations
    var note: String               // free-text note

    var isEmpty: Bool {
        workoutIDs.isEmpty && exerciseIDs.isEmpty && voiceActivityIDs.isEmpty &&
        timerIDs.isEmpty &&
        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(id: UUID = UUID(), dayOfWeek: Int, workoutIDs: [UUID] = [], exerciseIDs: [UUID] = [], voiceActivityIDs: [UUID] = [], timerIDs: [UUID] = [], note: String = "") {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.workoutIDs = workoutIDs
        self.exerciseIDs = exerciseIDs
        self.voiceActivityIDs = voiceActivityIDs
        self.timerIDs = timerIDs
        self.note = note
    }
}

// MARK: - Helpers

extension Int {
    /// Short day-of-week label, 0=Sun..6=Sat
    var dayOfWeekLabel: String {
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard self >= 0 && self < labels.count else { return "" }
        return labels[self]
    }
    var dayOfWeekFullLabel: String {
        let labels = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard self >= 0 && self < labels.count else { return "" }
        return labels[self]
    }
}
