//
//  ExtendApp.swift
//  Extend
//
//  Created by CAVAN MANNENBACH on 2/12/26.
//

import SwiftUI
import SwiftData
import HealthKit
import WidgetKit
import CloudKit

// MARK: - AppDelegate (handles silent push notifications from CloudKit)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        CloudKitSyncEngine.shared.handleRemoteNotification(userInfo)
        completionHandler(.newData)
    }
}

@main
struct ExtendApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let syncEngine = CloudKitSyncEngine.shared
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    let registry = ModuleRegistry.shared
    let state = ModuleState.shared
    let dashboardState = DashboardState.shared
    let exercisesState = ExercisesState.shared
    let workoutsState = WorkoutsState.shared
    let generateState = GenerateState.shared
    let muscleGroupsState = MuscleGroupsState.shared
    let equipmentState = EquipmentState.shared
    let workoutLogState = WorkoutLogState.shared
    let timerState = TimerState.shared
    let voiceTrainerState = VoiceTrainerState.shared
    let healthKitState = HealthKitState.shared
    let trainingPlanState = TrainingPlanState.shared
    let waterState = WaterState.shared
    let watchReceiver = WatchConnectivityReceiver.shared
    let mirroredWorkoutCoordinator = MirroredWorkoutCoordinator.shared

    init() {
        // Hook the HKHealthStore's mirror-start handler as early as possible.
        // Apple docs: "assign this property as soon as your app launches" so
        // the system can deliver a reconnecting mirror (after a transient
        // link drop mid-workout) even before SwiftUI renders the first body.
        MirroredWorkoutCoordinator.shared.registerMirrorHandler()

        // Register all modules synchronously before the first render so the
        // registry is never empty when ContentView draws its first frame.
        let registry = ModuleRegistry.shared
        let state = ModuleState.shared

        registry.registerModule(DashboardModule())
        registry.registerModule(WorkoutModule())
        registry.registerModule(TimerModule())
        registry.registerModule(ProgressModule())
        registry.registerModule(ExercisesModule())
        registry.registerModule(MuscleGroupsModule())
        registry.registerModule(EquipmentModule())
        registry.registerModule(GenerateModule())
        registry.registerModule(SettingsModule())
        registry.registerModule(VoiceTrainerModule())
        registry.registerModule(StickFigureAnimatorModule())
        registry.registerModule(MatchGameModule())
        registry.registerModule(TodaysPlanModule())
        registry.registerModule(WaterModule())

        // Set default navbar layout on first launch
        if state.topNavBarModules.isEmpty && state.bottomNavBarModules.isEmpty {
            state.setBottomNavBarModules([
                ModuleIDs.dashboard,
                ModuleIDs.workouts,
                ModuleIDs.exercises,
                ModuleIDs.todaysPlan,
                ModuleIDs.progress
            ])
            state.setTopNavBarModules([
                ModuleIDs.voiceTrainer,
                ModuleIDs.generate,
                ModuleIDs.timer,
                ModuleIDs.muscles,
                ModuleIDs.equipment,
                ModuleIDs.water,
                ModuleIDs.matchGame
            ])
        }

        // Auto-select the first module if nothing is persisted
        if state.selectedModuleID == nil,
           let first = registry.visibleModules.first {
            state.selectModule(first.id)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(DashboardState.shared)
                .environment(ModuleRegistry.shared)
                .environment(ModuleState.shared)
                .environment(exercisesState)
                .environment(workoutsState)
                .environment(generateState)
                .environment(muscleGroupsState)
                .environment(equipmentState)
                .environment(workoutLogState)
                .environment(timerState)
                .environment(voiceTrainerState)
                .environment(healthKitState)
                .environment(trainingPlanState)
                .environment(waterState)
                .environment(syncEngine)
                .onOpenURL { url in
                    guard url.scheme == "extend" else { return }
                    if url.host == "water" {
                        ModuleState.shared.selectModule(ModuleIDs.water)
                        if url.path == "/add" {
                            WaterState.shared.pendingOpenAddLog = true
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    waterState.importPendingWidgetLogs()
                    // Always refresh: after midnight rollover the cached widget total
                    // is yesterday's value until we re-stamp it for "today".
                    waterState.persistWidgetData()
                    trainingPlanState.refreshWidgetSnapshot()
                    Task {
                        await WorkoutLogState.shared.importFromHealthKit()
                        await waterState.syncFromHealthKit()
                    }
                }
                .task {
                    // Activate Watch ↔ iPhone sync
                    watchReceiver.activate()

                    // Import any water logs queued via widget quick-add buttons
                    waterState.importPendingWidgetLogs()

                    // Force a fresh widget stamp on launch so day-rollover wipes
                    // yesterday's cached value even when no logs are pending.
                    waterState.persistWidgetData()

                    // Refresh widget snapshot so Today's Plan widget has current data on launch
                    trainingPlanState.refreshWidgetSnapshot()

                    // Note: Watch complication settings are now managed directly on the Watch.
                    // Both iPhone and Watch write to the same App Group UserDefaults, so no
                    // WatchConnectivity sync is needed for settings.

                    // Start CloudKit sync (registers subscriptions, pulls latest data)
                    await CloudKitSyncEngine.shared.start()

                    // Request HealthKit auth on first launch if any sync is configured.
                    // Skip the prompt if already done — but still proceed to the
                    // import + observer setup below.
                    if !healthKitState.authorizationRequested,
                       HealthKitService.shared.isAvailable {
                        do {
                            try await HealthKitService.shared.requestAuthorization()
                            healthKitState.authorizationRequested = true
                        } catch {
                            // Non-fatal: user may have declined; we'll check status before each operation
                        }
                    }

                    // Pull any new HealthKit workouts/water that landed while we were closed,
                    // and subscribe to live updates so future workouts import on arrival.
                    await WorkoutLogState.shared.importFromHealthKit()
                    await waterState.syncFromHealthKit()
                    HealthKitService.shared.startObservingNewWorkouts {
                        Task { await WorkoutLogState.shared.importFromHealthKit() }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
