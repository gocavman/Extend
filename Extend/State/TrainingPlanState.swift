import Foundation
import Observation
import WidgetKit

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
        var items: [WidgetPlanItem] = []

        // Workouts
        if let data = wDefaults.data(forKey: "workouts_data"),
           let workouts = try? JSONDecoder().decode([Workout].self, from: data) {
            items += pd.workoutIDs.compactMap { id in
                workouts.first { $0.id == id }.map { WidgetPlanItem(name: $0.name, icon: "dumbbell.fill") }
            }
        }
        // Exercises
        if let data = wDefaults.data(forKey: "exercises_data"),
           let exercises = try? JSONDecoder().decode([Exercise].self, from: data) {
            items += pd.exerciseIDs.compactMap { id in
                exercises.first { $0.id == id }.map { WidgetPlanItem(name: $0.name, icon: "figure.strengthtraining.traditional") }
            }
        }
        // Voice trainers
        if let data = wDefaults.data(forKey: "VoiceTrainerConfigs"),
           let configs = try? JSONDecoder().decode([VoiceTrainerConfig].self, from: data) {
            items += pd.voiceActivityIDs.compactMap { id in
                configs.first { $0.id == id }.map { WidgetPlanItem(name: $0.name, icon: "waveform") }
            }
        }
        // Timers
        if let data = wDefaults.data(forKey: "timer_configs"),
           let configs = try? JSONDecoder().decode([TimerConfig].self, from: data) {
            items += pd.timerIDs.compactMap { id in
                configs.first { $0.id == id }.map { c in
                    WidgetPlanItem(name: c.name.isEmpty ? c.type.rawValue : c.name, icon: c.type.iconName)
                }
            }
        }

        writeWidgetSnapshot(planName: plan.name, items: items)
    }

    private func saveActiveID() {
        defaults.set(activePlanID?.uuidString, forKey: activeKey)
    }
}
