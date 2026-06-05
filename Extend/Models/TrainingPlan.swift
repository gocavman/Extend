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

    /// Returns the PlanDay for a given date, respecting week overrides.
    func planDay(for date: Date) -> PlanDay {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) - 1  // 0=Sun..6=Sat

        if weeks > 0 {
            // Compute which week of the program this date falls in
            let startOfStart = calendar.startOfDay(for: startDate)
            let startOfDate = calendar.startOfDay(for: date)
            let dayDiff = calendar.dateComponents([.day], from: startOfStart, to: startOfDate).day ?? 0
            let weekIndex = dayDiff / 7
            let key = String(weekIndex)
            if let overrideDays = weekOverrides[key],
               let day = overrideDays.first(where: { $0.dayOfWeek == weekday }) {
                return day
            }
        }

        return template.first(where: { $0.dayOfWeek == weekday }) ?? PlanDay(dayOfWeek: weekday)
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

    mutating func setTemplateDay(_ day: PlanDay) {
        if let idx = template.firstIndex(where: { $0.dayOfWeek == day.dayOfWeek }) {
            template[idx] = day
        }
    }

    mutating func setOverrideDay(_ day: PlanDay, forWeek weekIndex: Int) {
        let key = String(weekIndex)
        var days = weekOverrides[key] ?? []
        if let idx = days.firstIndex(where: { $0.dayOfWeek == day.dayOfWeek }) {
            days[idx] = day
        } else {
            days.append(day)
        }
        // Remove the entry entirely if all overrides are now empty
        let nonEmpty = days.filter { !$0.isEmpty }
        if nonEmpty.isEmpty {
            weekOverrides.removeValue(forKey: key)
        } else {
            weekOverrides[key] = days
        }
    }

    mutating func clearOverride(forWeek weekIndex: Int, dayOfWeek: Int) {
        let key = String(weekIndex)
        weekOverrides[key]?.removeAll { $0.dayOfWeek == dayOfWeek }
        if weekOverrides[key]?.isEmpty == true { weekOverrides.removeValue(forKey: key) }
    }
}

// MARK: - Plan Day

struct PlanDay: Identifiable, Codable {
    let id: UUID
    var dayOfWeek: Int          // 0 = Sunday … 6 = Saturday
    var workoutIDs: [UUID]      // ordered list of workouts for this day
    var exerciseIDs: [UUID]     // individual exercises
    var note: String            // free-text note

    var isEmpty: Bool {
        workoutIDs.isEmpty && exerciseIDs.isEmpty && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(id: UUID = UUID(), dayOfWeek: Int, workoutIDs: [UUID] = [], exerciseIDs: [UUID] = [], note: String = "") {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.workoutIDs = workoutIDs
        self.exerciseIDs = exerciseIDs
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
