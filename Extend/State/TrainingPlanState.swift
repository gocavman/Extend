import Foundation
import Observation

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
    }

    private func saveActiveID() {
        defaults.set(activePlanID?.uuidString, forKey: activeKey)
    }
}
