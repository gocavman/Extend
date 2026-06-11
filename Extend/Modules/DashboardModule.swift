////
////  DashboardModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import Observation
import UIKit

private let defaults = UserDefaults(suiteName: "group.com.cavanmannenbach.extend") ?? .standard

/// Dashboard module - the main landing page with customizable tiles
public struct DashboardModule: AppModule {
    public let id: UUID = ModuleIDs.dashboard
    public let displayName: String = "Dashboard"
    public let iconName: String = "square.grid.2x2"
    public let description: String = "Customizable dashboard with shortcuts and quick stats"

    public var order: Int = 0  // Always first
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        makeModuleView()
    }

    private func makeModuleView() -> AnyView {
        let view = DashboardModuleView(module: self)
        let wrapped: AnyView = AnyView(view)
        return wrapped
    }
}

// MARK: - Dashboard View

private struct DashboardModuleView: View {
    let module: DashboardModule

    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(DashboardState.self) var dashboardState
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var state
    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(WorkoutsState.self) var workoutsState
    @Environment(TimerState.self) var timerState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(VoiceTrainerState.self) var voiceTrainerState
    @Environment(TrainingPlanState.self) var planState

    @State private var quickStartWorkout: Workout? = nil
    @State private var showingPlanLauncher = false
    // Exercise direct sheets
    @State private var statsExercise: Exercise? = nil
    @State private var historyExercise: Exercise? = nil
    // Workout direct sheets
    @State private var statsWorkout: Workout? = nil
    @State private var historyWorkout: Workout? = nil
    // Timer direct sheets
    @State private var statsTimerConfig: TimerConfig? = nil
    @State private var historyTimerConfig: TimerConfig? = nil
    @State private var activeTimerConfig: TimerConfig? = nil
    // Voice trainer direct playback
    @State private var activeVoiceConfig: VoiceTrainerConfig? = nil
    @State private var statsVoiceConfig: VoiceTrainerConfig? = nil
    @State private var historyVoiceConfig: VoiceTrainerConfig? = nil
    
    @State private var spinningTiles: [UUID: Double] = [:]
    @State private var flyingTiles: Set<UUID> = []
    @State private var tileOffsets: [UUID: (x: CGFloat, y: CGFloat)] = [:]
    @State private var tileRotations: [UUID: Double] = [:]
    @State private var showBlankAlert = false
    @State private var blankAlertMessage = ""
    @State private var showingSettings = false
    
    // Track game levels for reactive UI updates
    @State private var matchGameLevel: Int = 1
    @State private var refreshTrigger: UUID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Reserve safe area at top so tiles don't bleed under the status bar
            Color.clear.frame(height: topNavBarHeight)

            // MARK: - Tiles Content
            if dashboardState.tiles.isEmpty {
                // Empty state
                emptyStateView
            } else {
                // Normal mode: show grid
                tilesGridView
            }
            
            Spacer()
        }
        .background(dashboardBackground)
        .tourAnchor(.dashboardBody)
        .overlay(alignment: .topTrailing) {
            floatingGearButton
                .tourAnchor(.settingsGear)
        }
        .alert("Blank Tile", isPresented: $showBlankAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(blankAlertMessage)
        }
        .fullScreenCover(item: $quickStartWorkout) { workout in
            StartWorkoutView(workout: workout)
                .environment(state)
                .environment(exercisesState)
                .environment(MuscleGroupsState.shared)
                .environment(EquipmentState.shared)
                .environment(WorkoutLogState.shared)
        }
        .fullScreenCover(isPresented: $showingPlanLauncher) {
            PlanDayLauncherSheet(
                onLaunchWorkout: { workout in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        quickStartWorkout = workout
                    }
                },
                onLaunchExercise: { exercise in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        quickStartWorkout = Workout(
                            name: "\(exercise.name)",
                            notes: "",
                            items: [.exercise(WorkoutExercise(exerciseID: exercise.id))]
                        )
                    }
                }
            )
            .environment(planState)
            .environment(workoutsState)
            .environment(exercisesState)
            .environment(voiceTrainerState)
            .environment(timerState)
            .environment(state)
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsModule().sheetView
        }
        .fullScreenCover(item: $statsExercise) { exercise in
            ExerciseStatsView(exercise: exercise)
                .environment(logState)
        }
        .fullScreenCover(item: $historyExercise) { exercise in
            ExerciseHistorySheet(exercise: exercise, logState: logState)
        }
        .fullScreenCover(item: $statsWorkout) { workout in
            WorkoutStatsView(workout: workout)
                .environment(logState)
        }
        .fullScreenCover(item: $historyWorkout) { workout in
            WorkoutHistorySheet(workout: workout, logState: logState)
        }
        .fullScreenCover(item: $activeTimerConfig) { config in
            ActiveTimerView(config: config)
        }
        .fullScreenCover(item: $statsTimerConfig) { config in
            TimerStatsView(config: config)
                .environment(logState)
        }
        .fullScreenCover(item: $historyTimerConfig) { config in
            TimerHistorySheet(config: config, logState: logState)
        }
        .fullScreenCover(item: $activeVoiceConfig) { config in
            VoiceTrainerPlaybackView(config: config, logState: logState)
        }
        .fullScreenCover(item: $statsVoiceConfig) { config in
            VoiceTrainerStatsView(config: config)
                .environment(logState)
        }
        .fullScreenCover(item: $historyVoiceConfig) { config in
            VoiceTrainerHistorySheet(config: config, logState: logState)
        }
        .onAppear {
            matchGameLevel = defaults.integer(forKey: "matchGameCurrentLevel")
            if matchGameLevel <= 0 { matchGameLevel = 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            matchGameLevel = defaults.integer(forKey: "matchGameCurrentLevel")
            if matchGameLevel <= 0 { matchGameLevel = 1 }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 44))
                .foregroundColor(.gray)
            
            Text("No tiles yet")
                .font(.headline)
            
            Text("Add tiles from Settings")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var tilesGridView: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width - 32
            let spacing: CGFloat = 6
            let columnWidth = (totalWidth - spacing * 2) / 3

            ScrollView {
                VStack(spacing: 20) {
                    let rows = tileRows()
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        tilesRowView(row: row, columnWidth: columnWidth, spacing: spacing)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private func tilesRowView(row: [DashboardTile], columnWidth: CGFloat, spacing: CGFloat) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(row, id: \.id) { tile in
                tileView(tile: tile, columnWidth: columnWidth, spacing: spacing)
            }
            if rowWidth(row) < 3 {
                Spacer(minLength: 0)
            }
        }
    }
    
    private func tileView(tile: DashboardTile, columnWidth: CGFloat, spacing: CGFloat) -> some View {
        let span = tile.size.columns
        let tileWidth = columnWidth * CGFloat(span) + spacing * CGFloat(span - 1)
        let isDoubleHeight = tile.tileType == .statCard
            && tile.statCardType == .muscleGroupDistribution
        // Dynamic-height entries for PR and 1RM tiles
        let prEntries: [(name: String, value: Double)] = tile.statCardType == .personalRecord ? personalRecordEntries(for: tile) : []
        let rmEntries: [(name: String, value: Double)] = tile.statCardType == .oneRepMax ? oneRMEntries(for: tile) : []
        // PR, 1RM, and todaysPlan tiles use content-driven height (nil) so layout flows naturally
        let dynamicEntryCount: Int = tile.statCardType == .personalRecord ? 1
            : tile.statCardType == .oneRepMax ? 1
            : tile.statCardType == .todaysPlan ? 1
            : 0
        let isIPad = sizeClass == .regular
        // favoriteDay: header(44) + 7 rows × 19pt each + bottom padding(12) ≈ 189
        // volumeThisWeek: header(44) + bars(107) + trend(20) + padding(16) ≈ 187
        let tileHeight: CGFloat = isDoubleHeight ? columnWidth * 2 + spacing
            : tile.statCardType == .favoriteDay ? CGFloat(44 + 7 * 19 + 12) * (isIPad ? 1.6 : 1.0)
            : tile.statCardType == .volumeThisWeek ? CGFloat(44 + 107 + 20 + 16) * (isIPad ? 1.6 : 1.0)
            : tile.statCardType == .workoutFrequency ? CGFloat(isIPad ? 130 : 110)
            : columnWidth
        
        return Group {
            if tile.tileType == .statCard, let statCard = tile.statCardType, statCard == .todaysPlan {
                TodaysPlanTileView(
                    tileTint: tile.tileTintColor,
                    defaultBackground: state.dashboardTileBackgroundColor,
                    borderColor: state.dashboardTileBorderColor,
                    accentPlacement: tile.accentPlacement,
                    accentColor: tile.accentColor,
                    onLaunch: { showingPlanLauncher = true }
                )
                .frame(width: tileWidth)
                .rotationEffect(.degrees(tileRotations[tile.id] ?? 0))
                .offset(
                    x: tileOffsets[tile.id]?.x ?? 0,
                    y: tileOffsets[tile.id]?.y ?? 0
                )
                .opacity(flyingTiles.contains(tile.id) ? 0.3 : 1.0)
                .animation(.easeOut(duration: 2.5), value: tileRotations[tile.id])
                .animation(.easeOut(duration: 2.5), value: tileOffsets[tile.id]?.x)
                .animation(.easeOut(duration: 2.5), value: tileOffsets[tile.id]?.y)
                .animation(.easeOut(duration: 2.5), value: flyingTiles.contains(tile.id))
            } else if tile.tileType == .statCard, let statCard = tile.statCardType {
                StatCardTileView(
                    title: tile.title,
                    icon: tile.icon,
                    value: statValue(for: statCard),
                    statType: statCard,
                    frequencyDays: workoutFrequencyDays(),
                    frequencyRangeLabel: workoutFrequencyRangeLabel(),
                    muscleSegments: muscleDistributionSegments(),
                    accentPlacement: tile.accentPlacement,
                    accentColor: tile.accentColor,
                    tileTint: tile.tileTintColor,
                    defaultBackground: state.dashboardTileBackgroundColor,
                    borderColor: state.dashboardTileBorderColor,
                    trend: trendInfo(for: statCard),
                    personalRecordLabel: statCard == .personalRecord ? logState.personalRecord?.exerciseName : nil,
                    oneRMEntries: rmEntries,
                    personalRecordEntries: prEntries,
                    volumeWeeks: statCard == .volumeThisWeek ? logState.volumeByWeek(weeks: 7, workoutName: tile.volumeWorkoutName, exerciseID: tile.volumeExerciseID) : [],
                    dayOfWeekCounts: statCard == .favoriteDay ? logState.workoutCountByDayOfWeek : []
                )
                .frame(width: tileWidth, height: dynamicEntryCount > 0 ? nil : tileHeight)
                .rotationEffect(.degrees(tileRotations[tile.id] ?? 0))
                .offset(
                    x: tileOffsets[tile.id]?.x ?? 0,
                    y: tileOffsets[tile.id]?.y ?? 0
                )
                .opacity(flyingTiles.contains(tile.id) ? 0.3 : 1.0)
                .animation(.easeOut(duration: 2.5), value: tileRotations[tile.id])
                .animation(.easeOut(duration: 2.5), value: tileOffsets[tile.id]?.x)
                .animation(.easeOut(duration: 2.5), value: tileOffsets[tile.id]?.y)
                .animation(.easeOut(duration: 2.5), value: flyingTiles.contains(tile.id))
            } else {
                interactiveTileView(tile: tile, width: tileWidth, height: tileHeight)
            }
        }
    }
    
    private func interactiveTileView(tile: DashboardTile, width: CGFloat, height: CGFloat) -> some View {
        let bg: Color = tile.tileTintColor ?? state.dashboardTileBackgroundColor ?? Color(UIColor.secondarySystemBackground)
        let tileBorder: Color = tile.tileTintColor != nil ? .clear : (state.dashboardTileBorderColor ?? .clear)
        let isThreePieceShortcut = tile.tileType == .shortcut &&
            (tile.shortcutType == .workout || tile.shortcutType == .timer ||
             tile.shortcutType == .voiceTrainer || tile.shortcutType == .quickExercise)

        return Group {
            if isThreePieceShortcut {
                // 3-piece tile: top=launch, bottom-left=stats, bottom-right=history
                ZStack(alignment: .leading) {
                    VStack(spacing: 0) {
                        // Top: launch button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if tile.shortcutType == .workout, let itemID = tile.shortcutItemID,
                               let workout = workoutsState.workouts.first(where: { $0.id == itemID }) {
                                quickStartWorkout = workout
                            } else if tile.shortcutType == .timer, let itemID = tile.shortcutItemID,
                                      let config = timerState.configs.first(where: { $0.id == itemID }) {
                                activeTimerConfig = config
                            } else if tile.shortcutType == .voiceTrainer, let itemID = tile.shortcutItemID {
                                activeVoiceConfig = voiceTrainerState.savedConfigurations.first { $0.id == itemID }
                            } else if tile.shortcutType == .quickExercise, let itemID = tile.shortcutItemID,
                                      let exercise = exercisesState.exercises.first(where: { $0.id == itemID }) {
                                quickStartWorkout = Workout(
                                    name: "\(exercise.name)",
                                    notes: "",
                                    items: [WorkoutItem.exercise(WorkoutExercise(exerciseID: exercise.id))],
                                    healthKitActivityType: exercise.healthKitActivityType
                                )
                            }
                        }) {
                            VStack(spacing: 5) {
                                Image(systemName: tile.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                if !tile.title.isEmpty {
                                    Text(tile.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: height - 33)
                        }
                        .buttonStyle(.plain)

                        Divider()

                        // Bottom: stats (left) + history (right)
                        HStack(spacing: 0) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if tile.shortcutType == .workout, let itemID = tile.shortcutItemID {
                                    statsWorkout = workoutsState.workouts.first { $0.id == itemID }
                                } else if tile.shortcutType == .timer, let itemID = tile.shortcutItemID {
                                    statsTimerConfig = timerState.configs.first { $0.id == itemID }
                                } else if tile.shortcutType == .voiceTrainer, let itemID = tile.shortcutItemID {
                                    statsVoiceConfig = voiceTrainerState.savedConfigurations.first { $0.id == itemID }
                                } else if tile.shortcutType == .quickExercise, let itemID = tile.shortcutItemID {
                                    statsExercise = exercisesState.exercises.first { $0.id == itemID }
                                }
                            }) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                            }
                            .buttonStyle(.plain)

                            Divider().frame(height: 20)

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if tile.shortcutType == .workout, let itemID = tile.shortcutItemID {
                                    historyWorkout = workoutsState.workouts.first { $0.id == itemID }
                                } else if tile.shortcutType == .timer, let itemID = tile.shortcutItemID {
                                    historyTimerConfig = timerState.configs.first { $0.id == itemID }
                                } else if tile.shortcutType == .voiceTrainer, let itemID = tile.shortcutItemID {
                                    historyVoiceConfig = voiceTrainerState.savedConfigurations.first { $0.id == itemID }
                                } else if tile.shortcutType == .quickExercise, let itemID = tile.shortcutItemID {
                                    historyExercise = exercisesState.exercises.first { $0.id == itemID }
                                }
                            }) {
                                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(bg)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(tileBorder, lineWidth: 1))

                    if tile.accentPlacement != .none {
                        AccentBarView(placement: tile.accentPlacement, color: tile.accentColor)
                    }
                }
                .frame(width: width, height: height)
            } else {
                // Standard single-button tile
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isBlankTile(tile) {
                        handleBlankTileAction(tile)
                    } else if let targetID = findModuleID(for: tile) {
                        state.selectModule(targetID)
                    }
                }) {
                    ZStack(alignment: .leading) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)

                            Image(systemName: tile.icon)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.primary)
                                .rotationEffect(.degrees(spinningTiles[tile.id] ?? 0))
                                .animation(.easeInOut(duration: 1.0), value: spinningTiles[tile.id])

                            if !tile.title.isEmpty {
                                Text(tile.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }

                            Spacer(minLength: 0)

                            // Show game levels at bottom
                            if tile.targetModuleID == ModuleIDs.matchGame {
                                Text("Level \(matchGameLevel)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.bottom, 4)
                            } else if isBlankTile(tile), let count = dashboardState.tileClickCounts[tile.id], count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.bottom, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(10)
                        .background(bg)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tileBorder, lineWidth: 1))
                        .foregroundColor(.primary)

                        // Accent bar overlay
                        if tile.accentPlacement != .none {
                            AccentBarView(placement: tile.accentPlacement, color: tile.accentColor)
                        }
                    }
                }
                .frame(width: width, height: height)
            }
        }
        .rotationEffect(.degrees(tileRotations[tile.id] ?? 0))
        .offset(
            x: tileOffsets[tile.id]?.x ?? 0,
            y: tileOffsets[tile.id]?.y ?? 0
        )
        .opacity(flyingTiles.contains(tile.id) ? 0.3 : 1.0)
        .animation(.easeOut(duration: 2.5), value: tileRotations[tile.id])
        .animation(.easeOut(duration: 2.5), value: tileOffsets[tile.id]?.x)
        .animation(.easeOut(duration: 2.5), value: tileOffsets[tile.id]?.y)
        .animation(.easeOut(duration: 2.5), value: flyingTiles.contains(tile.id))
    }

    private var floatingGearButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingSettings = true
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 18))
                .foregroundColor(Color.primary.opacity(0.7))
                .padding(10)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 6)
        .padding(.top, topNavBarHeight)
    }

    // Returns the height needed to clear the top safe area when no top navbar is present.
    // When a top navbar exists it already handles safe area, so no extra padding is needed.
    private var topNavBarHeight: CGFloat {
        let hasTopBar = !ModuleState.shared.topNavBarModules.isEmpty
        if hasTopBar { return 0 }
        // Use the key window's safe area top inset
        let inset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 0
        return inset
    }

    @ViewBuilder
    private var dashboardBackground: some View {
        let baseColor = state.dashboardBackgroundColor ?? Color(UIColor.systemBackground)
        if state.dashboardUseGradient {
            LinearGradient(
                colors: [baseColor, state.dashboardGradientSecondaryColor],
                startPoint: state.dashboardGradientDirection.startPoint,
                endPoint: state.dashboardGradientDirection.endPoint
            )
        } else {
            baseColor
        }
    }

    // MARK: - Helper Methods
    
    private func findModuleID(for tile: DashboardTile) -> UUID? {
        // Old game1 UUID — redirect any saved tiles to the stick figure animator
        let oldGame1ID = UUID(uuidString: "0000000C-0000-0000-0000-000000000000")!

        // Prefer an explicit target when available
        if let targetID = tile.targetModuleID {
            if targetID == oldGame1ID { return ModuleIDs.stickFigureAnimator }
            return targetID
        }

        // Try to find a module matching the tile's title
        let modules = registry.registeredModules
        if let module = modules.first(where: { $0.displayName.lowercased() == tile.title.lowercased() }) {
            return module.id
        }

        return nil
    }
    
    private func isBlankTile(_ tile: DashboardTile) -> Bool {
        tile.targetModuleID == nil && tile.tileType == .moduleShortcut && tile.statCardType == nil
    }
    
    private func handleBlankTileAction(_ tile: DashboardTile) {
        // Increment click counter using persisted state
        dashboardState.incrementClickCount(for: tile.id)
        
        switch tile.blankAction ?? .animation1 {
        case .animation1:
            // Spinning wheel animation - multiple spins with deceleration
            let spins = Double.random(in: 3...5)  // 3-5 full rotations
            let totalDegrees = spins * 360
            withAnimation(.easeOut(duration: 2.5)) {
                spinningTiles[tile.id, default: 0] += totalDegrees
            }
        case .animation2:
            blankAlertMessage = "Animation 2 Coming Soon"
            showBlankAlert = true
        case .animation3:
            blankAlertMessage = "Animation 3 Coming Soon"
            showBlankAlert = true
        case .game2:
            blankAlertMessage = "Game 2 coming soon"
            showBlankAlert = true
        }
    }
    
    private func statValue(for stat: StatCardType) -> String {
        switch stat {
        case .totalWorkouts:
            return "\(logState.totalWorkouts)"
        case .dayStreaks:
            return "\(logState.currentStreak)"
        case .totalTime:
            let totalSeconds = Int(logState.totalTime)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        case .favoriteExercise:
            return logState.favoriteExercise ?? "—"
        case .favoriteDay:
            return logState.favoriteDay ?? "—"
        case .workoutFrequency:
            let frequency = logState.workoutFrequency(days: 14)
            let total = frequency.values.reduce(0, +)
            return "\(total) / 14d"
        case .muscleGroupDistribution:
            let segments = muscleDistributionSegments()
            return segments.first?.label ?? "—"
        case .volumeThisWeek:
            let v = logState.volumeThisWeek
            if v >= 1000 {
                return String(format: "%.1fk", v / 1000)
            }
            return String(format: "%.0f", v)
        case .longestStreak:
            return "\(logState.longestStreak)"
        case .restDays:
            return "\(logState.restDaysLast14)"
        case .personalRecord:
            if let pr = logState.personalRecord {
                return String(format: "%.0f \(weightUnit)", pr.weight)
            }
            return "—"
        case .oneRepMax:
            // Value not shown as text; tile renders its own leaderboard list
            return ""
        case .todaysPlan:
            // Value not shown as text; tile renders its own plan content
            return ""
        }
    }

    /// Returns an optional trend arrow (↑ / ↓) and color for stats that support comparison
    private func trendInfo(for stat: StatCardType) -> (symbol: String, color: Color)? {
        switch stat {
        case .totalWorkouts:
            let this = logState.workoutsThisWeek
            let last = logState.workoutsLastWeek
            if last == 0 { return nil }
            return this > last ? ("↑", .green) : this < last ? ("↓", .red) : nil
        case .dayStreaks:
            // Show up arrow if current streak > 0, no comparison available without history
            return logState.currentStreak > 0 ? ("↑", .green) : nil
        case .volumeThisWeek:
            let this = logState.volumeThisWeek
            let last = logState.volumeLastWeek
            if last == 0 { return nil }
            return this > last ? ("↑", .green) : this < last ? ("↓", .red) : nil
        default:
            return nil
        }
    }

    private func personalRecordEntries(for tile: DashboardTile) -> [(name: String, value: Double)] {
        if let ids = tile.personalRecordExerciseIDs, !ids.isEmpty {
            return ids.compactMap { id in
                guard let weight = logState.bestWeight(exerciseID: id) else { return nil }
                let name = logState.logs
                    .flatMap { $0.exercises }
                    .first(where: { $0.exerciseID == id })?.exerciseName ?? "Unknown"
                return (name: name, value: weight)
            }
            .sorted { $0.value > $1.value }
        } else {
            return logState.topExercisesByWeight(limit: 5)
                .map { (name: $0.exerciseName, value: $0.weight) }
        }
    }

    private func oneRMEntries(for tile: DashboardTile) -> [(name: String, value: Double)] {
        if let ids = tile.oneRMExerciseIDs, !ids.isEmpty {
            // User-selected exercises
            return ids.compactMap { id in
                guard let value = logState.bestEstimated1RM(exerciseID: id) else { return nil }
                // Find display name from any log
                let name = logState.logs
                    .flatMap { $0.exercises }
                    .first(where: { $0.exerciseID == id })?.exerciseName ?? "Unknown"
                return (name: name, value: value)
            }
            .sorted { $0.value > $1.value }
        } else {
            // Auto top-5 by best 1RM
            return logState.topExercisesBy1RM(limit: 5)
                .map { (name: $0.exerciseName, value: $0.estimated1RM) }
        }
    }

    private func workoutFrequencyDays() -> [WeekdayFrequency] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -13, to: endDate) ?? endDate
        var result: [WeekdayFrequency] = []

        var date = startDate
        while date <= endDate {
            let logs = logState.logsForDate(date)
            let workoutCount = logs.count
            let label = DateFormatter.weekdayInitial(from: date)
            result.append(
                WeekdayFrequency(
                    label: label,
                    hasWorkout: workoutCount > 0
                )
            )
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? endDate
            if result.count == 14 { break }
        }

        return result
    }

    private func workoutFrequencyRangeLabel() -> String {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -13, to: endDate) ?? endDate
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startDate))–\(formatter.string(from: endDate))"
    }

    private func muscleDistributionSegments() -> [PieSegment] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
        let recentLogs = logState.logsInRange(from: startDate, to: endDate)

        var counts: [String: Int] = [:]
        for log in recentLogs {
            // For logs with directly-assigned muscle groups (e.g. VoiceTrainer), count those
            let directMuscleIDs = log.primaryMuscleGroupIDs + log.secondaryMuscleGroupIDs
            if !directMuscleIDs.isEmpty {
                let names = directMuscleIDs.compactMap { id in
                    muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                }
                for name in names {
                    counts[name, default: 0] += 1
                }
            }
            // For exercise-based logs, look up muscle groups from each exercise definition
            for exercise in log.exercises {
                if let sourceExercise = exercisesState.exercises.first(where: { $0.id == exercise.exerciseID }) {
                    let muscleIDs = sourceExercise.primaryMuscleGroupIDs + sourceExercise.secondaryMuscleGroupIDs
                    let names = muscleIDs.compactMap { id in
                        muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                    }
                    for name in names {
                        counts[name, default: 0] += 1
                    }
                }
            }
        }

        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [] }

        // Stable sort: sort by value descending, then by name ascending for ties
        let sorted = counts.sorted {
            if $0.value == $1.value {
                return $0.key < $1.key
            }
            return $0.value > $1.value
        }
        
        let top = Array(sorted.prefix(7))
        let remainder = sorted.dropFirst(7)
        let otherCount = remainder.reduce(0) { $0 + $1.value }
        let colors: [Color] = [.black, .red, .blue, .green, .orange, .purple, .pink, .brown]

        var segments: [PieSegment] = top.enumerated().map { index, item in
            let percentage = Double(item.value) / Double(total)
            return PieSegment(label: item.key, value: percentage, color: colors[index % colors.count])
        }

        if otherCount > 0 {
            let percentage = Double(otherCount) / Double(total)
            segments.append(PieSegment(label: "Other", value: percentage, color: .gray))
        }

        // Don't re-sort - the segments are already in the correct order
        // Just ensure "Other" is at the end if it exists
        if let otherIndex = segments.firstIndex(where: { $0.label == "Other" }), otherIndex < segments.count - 1 {
            let other = segments.remove(at: otherIndex)
            segments.append(other)
        }

        return segments
    }

    private func tileRows() -> [[DashboardTile]] {
        let tiles = dashboardState.tiles.sorted { $0.order < $1.order }
        var rows: [[DashboardTile]] = []
        var currentRow: [DashboardTile] = []
        var remaining = 3

        for tile in tiles {
            let span = tile.size.columns
            if span > 3 { continue }
            if span > remaining {
                rows.append(currentRow)
                currentRow = [tile]
                remaining = 3 - span
            } else {
                currentRow.append(tile)
                remaining -= span
            }
            if remaining == 0 {
                rows.append(currentRow)
                currentRow = []
                remaining = 3
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }

    private func rowWidth(_ row: [DashboardTile]) -> Int {
        row.reduce(0) { $0 + $1.size.columns }
    }

    private func calculateDogPosition(basePosition: CGPoint, phase: Double, screenSize: CGSize = CGSize(width: 390, height: 844)) -> CGPoint {
        // Screen dimensions
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let padding: CGFloat = 20
        
        // Calculate perimeter corners
        let top = padding
        let bottom = screenHeight - padding
        let left = padding
        let right = screenWidth - padding
        
        // Calculate perimeter segments
        let horizontalDistance = right - left
        let verticalDistance = bottom - top
        let totalPerimeter = 2 * (horizontalDistance + verticalDistance)
        
        // Normalize phase to 0-1 range and calculate distance along perimeter
        let normalizedPhase = phase.truncatingRemainder(dividingBy: 1.0)
        let distanceAlongPerimeter = normalizedPhase * totalPerimeter
        
        // Determine which segment of the perimeter and position
        var x: CGFloat = left
        var y: CGFloat = top
        let remainingDistance = distanceAlongPerimeter
        
        // Top edge: left to right
        if remainingDistance <= horizontalDistance {
            x = left + remainingDistance
            y = top
        }
        // Right edge: top to bottom
        else if remainingDistance <= horizontalDistance + verticalDistance {
            x = right
            y = top + (remainingDistance - horizontalDistance)
        }
        // Bottom edge: right to left
        else if remainingDistance <= 2 * horizontalDistance + verticalDistance {
            x = right - (remainingDistance - horizontalDistance - verticalDistance)
            y = bottom
        }
        // Left edge: bottom to top
        else {
            x = left
            y = bottom - (remainingDistance - 2 * horizontalDistance - verticalDistance)
        }
        
        return CGPoint(x: x, y: y)
    }

}

// MARK: - Add Tile Sheet

private struct AddTileSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ModuleRegistry.self) var registry
    @Environment(DashboardState.self) var dashboardState

    @State private var title: String = ""
    @State private var selectedIcon: String = "square"
    @State private var selectedType: TileType = .moduleShortcut
    @State private var selectedModuleID: UUID? = nil
    @State private var selectedStatCard: StatCardType? = nil
    @State private var selectedModuleIDs: Set<UUID> = []
    @State private var selectedStatCards: Set<StatCardType> = []
    @State private var selectedBlankIcon: String? = nil
    @State private var selectedBlankAction: BlankTileAction = .animation1
    @State private var hasInitialized: Bool = false

    let onAdd: (DashboardTile) -> Void

    private let icons = [
        "dumbbell", "dumbbell.fill", "heart", "heart.fill", "lungs", "lungs.fill",
        "timer", "chart.line.uptrend.xyaxis", "flame", "target", "star", "bolt", "gear", "square.grid.2x2", "sparkles", "clock", "trophy", "leaf", "sun.max", "moon",
        "eye", "brain", "staroflife.fill", "cross", "cup.and.saucer.fill", "wineglass", "mug.fill",
        "pi", "number", "lightbulb.fill",
        "figure.strengthtraining.traditional", "figure.walk.treadmill", "figure.walk", "person.fill",
        "figure.run", "figure.boxing", "figure.cooldown", "figure.core.training", "figure.cross.training", "figure.dance", "figure.golf", "figure.gymnastics", "figure.yoga", "figure", "figure.hiking", "figure.kickboxing",
        "figure.mind.and.body", "figure.outdoor.cycle", "figure.rower", "figure.stairs",
        "tortoise.fill", "dog.fill", "cat.fill", "pawprint.fill", "lizard.fill", "bird.fill", "ant.fill", "hare.fill", "fish.fill", "fossil.shell.fill", "atom", "tree.fill"
    ]

    private var moduleQuickOptions: [AnyAppModule] {
        let existingTileModuleIDs = Set(dashboardState.tiles.compactMap { $0.targetModuleID })
        return registry.registeredModules
            .filter { !existingTileModuleIDs.contains($0.id) && $0.displayName != "Dashboard" && $0.id != ModuleIDs.matchGame && $0.id != ModuleIDs.stickFigureAnimator }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var statCardOptions: [StatCardType] {
        let used = Set(dashboardState.tiles.compactMap { $0.statCardType })
        // volumeThisWeek can be added multiple times (each instance can be filtered differently)
        return StatCardType.allCases.filter { !used.contains($0) || $0 == .volumeThisWeek }
    }

    private var hasSelection: Bool {
        !selectedModuleIDs.isEmpty || !selectedStatCards.isEmpty || selectedBlankIcon != nil
    }

    private func isMiniGameSelected() -> Bool {
        selectedBlankIcon != nil && selectedBlankAction == .game2
    }

    private func iconForStatCard(_ statCard: StatCardType) -> String {
        switch statCard {
        case .totalWorkouts:
            return "list.bullet"
        case .dayStreaks:
            return "flame"
        case .totalTime:
            return "clock"
        case .favoriteExercise:
            return "star"
        case .favoriteDay:
            return "calendar"
        case .workoutFrequency:
            return "chart.bar"
        case .muscleGroupDistribution:
            return "chart.pie"
        case .volumeThisWeek:
            return "scalemass"
        case .longestStreak:
            return "trophy"
        case .restDays:
            return "moon"
        case .personalRecord:
            return "medal"
        case .oneRepMax:
            return "trophy.fill"
        case .todaysPlan:
            return "calendar.badge.checkmark"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Option") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pick modules or stat cards")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Section("Modules") {
                    ForEach(moduleQuickOptions, id: \.id) { module in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if selectedModuleIDs.contains(module.id) {
                                selectedModuleIDs.remove(module.id)
                            } else {
                                selectedModuleIDs.insert(module.id)
                            }
                        }) {
                            HStack {
                                Text(module.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedModuleIDs.contains(module.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Stat Cards") {
                    if statCardOptions.isEmpty {
                        Text("All stat cards are already added")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        ForEach(statCardOptions, id: \.self) { stat in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if selectedStatCards.contains(stat) {
                                    selectedStatCards.remove(stat)
                                } else {
                                    selectedStatCards.insert(stat)
                                }
                            }) {
                                HStack {
                                    Text(stat.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedStatCards.contains(stat) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.primary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Mini Games") {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if selectedModuleIDs.contains(ModuleIDs.matchGame) {
                            selectedModuleIDs.remove(ModuleIDs.matchGame)
                        } else {
                            selectedModuleIDs.insert(ModuleIDs.matchGame)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Workout Match")
                                    .foregroundColor(.primary)
                                Text("500 levels of match-3. Collect powerups and level up.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedModuleIDs.contains(ModuleIDs.matchGame) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section("Animator") {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if selectedModuleIDs.contains(ModuleIDs.stickFigureAnimator) {
                            selectedModuleIDs.remove(ModuleIDs.stickFigureAnimator)
                        } else {
                            selectedModuleIDs.insert(ModuleIDs.stickFigureAnimator)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stick Figure Animator")
                                    .foregroundColor(.primary)
                                Text("Build stick figure poses frame by frame and export animated GIFs for your exercises.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedModuleIDs.contains(ModuleIDs.stickFigureAnimator) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section("Blank Tile") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach([BlankTileAction.animation1, BlankTileAction.animation2, BlankTileAction.animation3], id: \.self) { action in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedBlankAction = action
                            }) {
                                HStack {
                                    Text(action.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedBlankAction == action && !isMiniGameSelected() {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.primary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("Select Icon")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedBlankIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .frame(maxWidth: .infinity, maxHeight: 44)
                                        .background(selectedBlankIcon == icon && !isMiniGameSelected() ? Color.primary.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(8)
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Tile")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        for statCard in selectedStatCards {
                            let size: TileSize = (statCard == .workoutFrequency || statCard == .muscleGroupDistribution || statCard == .oneRepMax || statCard == .personalRecord) ? .large : .small
                            let tile = DashboardTile(
                                title: statCard.rawValue,
                                icon: iconForStatCard(statCard),
                                order: dashboardState.tiles.count,
                                tileType: .statCard,
                                statCardType: statCard,
                                size: size
                            )
                            onAdd(tile)
                        }

                        for moduleID in selectedModuleIDs {
                            if let module = registry.registeredModules.first(where: { $0.id == moduleID }) {
                                let tile = DashboardTile(
                                    title: module.displayName,
                                    icon: module.iconName,
                                    order: dashboardState.tiles.count,
                                    targetModuleID: module.id,
                                    tileType: .moduleShortcut,
                                    size: .small
                                )
                                onAdd(tile)
                            }
                        }

                        if let blankIcon = selectedBlankIcon {
                            let tile = DashboardTile(
                                title: "",
                                icon: blankIcon,
                                order: dashboardState.tiles.count,
                                targetModuleID: nil,
                                tileType: .moduleShortcut,
                                size: .small,
                                blankAction: selectedBlankAction
                            )
                            onAdd(tile)
                        }

                        if hasSelection {
                            dismiss()
                        }
                    }
                    .disabled(!hasSelection)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            #endif
        }
    }
}

// MARK: - Edit Tile Sheet

private struct EditTileSheet: View {
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @Environment(\.dismiss) var dismiss
    @Environment(ExercisesState.self) var exercisesState
    @Environment(WorkoutLogState.self) var logState
    @Environment(WorkoutsState.self) var workoutsState

    let tile: DashboardTile
    
    @State private var title: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedSize: TileSize = .small
    /// For 1RM tiles: nil = auto top-5; non-nil = user-chosen set
    @State private var oneRMExerciseIDs: [UUID]? = nil
    /// For PR tiles: nil = auto top-5 by weight; non-nil = user-chosen set
    @State private var personalRecordExerciseIDs: [UUID]? = nil
    /// For Volume tiles: nil = all workouts; non-nil = specific workout name
    @State private var volumeWorkoutName: String? = nil
    /// For Volume tiles: nil = all exercises; non-nil = specific exercise ID
    @State private var volumeExerciseID: UUID? = nil

    let onSave: (DashboardTile) -> Void

    private let icons = [
        "dumbbell", "dumbbell.fill", "heart", "heart.fill", "suit.club.fill", "suit.diamond.fill", "suit.spade.fill", "lungs", "lungs.fill",
        "timer", "chart.line.uptrend.xyaxis", "flame", "target", "star", "bolt", "gear", "square.grid.2x2", "sparkles", "clock", "trophy", "leaf", "sun.max", "moon",
        "eye", "brain", "staroflife.fill", "cross", "cup.and.saucer.fill", "wineglass", "mug.fill",
        "pi", "number", "lightbulb.fill",
        "figure.strengthtraining.traditional", "figure.walk.treadmill", "figure.walk", "person.fill",
        "figure.run", "figure.boxing", "figure.cooldown", "figure.core.training", "figure.cross.training", "figure.dance", "figure.golf", "figure.gymnastics", "figure.yoga", "figure", "figure.hiking", "figure.kickboxing",
        "figure.mind.and.body", "figure.outdoor.cycle", "figure.rower", "figure.stairs",
        "tortoise.fill", "dog.fill", "cat.fill", "pawprint.fill", "lizard.fill", "bird.fill", "ant.fill", "hare.fill", "fish.fill", "fossil.shell.fill", "atom", "tree.fill"
    ]
    
    private func availableSizes() -> [TileSize] {
        if tile.tileType == .graph {
            return [.large]
        }
        if tile.tileType == .statCard, let statCard = tile.statCardType {
            if statCard == .workoutFrequency || statCard == .muscleGroupDistribution
                || statCard == .volumeThisWeek || statCard == .favoriteDay {
                return [.large]
            }
            if statCard == .oneRepMax || statCard == .personalRecord {
                return [.medium, .large]
            }
        }
        return TileSize.allCases
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tile Details") {
                    TextField("Title", text: $title)
                }

                Section("Tile Size") {
                    Picker("Size", selection: $selectedSize) {
                        ForEach(availableSizes(), id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 1RM exercise selection — only shown for the 1RM Leaderboard tile
                if tile.statCardType == .oneRepMax {
                    Section {
                        // Exercises that have 1RM history (at least one qualifying set logged)
                        let eligibleExercises = exercisesState.exercises
                            .filter { logState.bestEstimated1RM(exerciseID: $0.id) != nil }
                            .sorted { $0.name < $1.name }

                        if eligibleExercises.isEmpty {
                            Text("Log sets with 3–10 reps on any exercise to populate this list.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            let selected = oneRMExerciseIDs ?? []
                            ForEach(eligibleExercises) { exercise in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    var ids = oneRMExerciseIDs ?? []
                                    if ids.contains(exercise.id) {
                                        ids.removeAll { $0 == exercise.id }
                                    } else if ids.count < 5 {
                                        ids.append(exercise.id)
                                    }
                                    oneRMExerciseIDs = ids.isEmpty ? nil : ids
                                }) {
                                    HStack {
                                        Text(exercise.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if let rm = logState.bestEstimated1RM(exerciseID: exercise.id) {
                                            Text(String(format: "%.0f \(weightUnit)", rm))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if selected.contains(exercise.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Exercises (up to 5)")
                    } footer: {
                        Text(oneRMExerciseIDs == nil ? "Showing auto top-5 by best 1RM. Select exercises to pin specific ones." : "Deselect all to revert to auto top-5.")
                            .font(.caption)
                    }
                }

                // PR exercise selection — only shown for Personal Record tile
                if tile.statCardType == .personalRecord {
                    Section {
                        let eligibleExercises = exercisesState.exercises
                            .filter { logState.bestWeight(exerciseID: $0.id) != nil }
                            .sorted { $0.name < $1.name }

                        if eligibleExercises.isEmpty {
                            Text("Log sets with weights on any exercise to populate this list.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            let selected = personalRecordExerciseIDs ?? []
                            ForEach(eligibleExercises) { exercise in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    var ids = personalRecordExerciseIDs ?? []
                                    if ids.contains(exercise.id) {
                                        ids.removeAll { $0 == exercise.id }
                                    } else if ids.count < 5 {
                                        ids.append(exercise.id)
                                    }
                                    personalRecordExerciseIDs = ids.isEmpty ? nil : ids
                                }) {
                                    HStack {
                                        Text(exercise.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if let w = logState.bestWeight(exerciseID: exercise.id) {
                                            Text(String(format: "%.0f \(weightUnit)", w))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if selected.contains(exercise.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Exercises (up to 5)")
                    } footer: {
                        Text(personalRecordExerciseIDs == nil ? "Showing auto top-5 by best weight. Select exercises to pin specific ones." : "Deselect all to revert to auto top-5.")
                            .font(.caption)
                    }
                }

                // Volume This Week: workout and exercise filter
                if tile.statCardType == .volumeThisWeek {
                    Section {
                        // Workout filter — pick from saved workouts (or clear for all)
                        let workoutNames = workoutsState.workouts.map { $0.name }.sorted()
                        if workoutNames.isEmpty {
                            Text("No saved workouts yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            // "All Workouts" row
                            Button(action: { volumeWorkoutName = nil; volumeExerciseID = nil }) {
                                HStack {
                                    Text("All Workouts")
                                    Spacer()
                                    if volumeWorkoutName == nil {
                                        Image(systemName: "checkmark").foregroundColor(.primary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            ForEach(workoutNames, id: \.self) { name in
                                Button(action: {
                                    volumeWorkoutName = (volumeWorkoutName == name) ? nil : name
                                    volumeExerciseID = nil
                                }) {
                                    HStack {
                                        Text(name)
                                        Spacer()
                                        if volumeWorkoutName == name {
                                            Image(systemName: "checkmark").foregroundColor(.primary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Filter by Workout")
                    } footer: {
                        Text(volumeWorkoutName == nil ? "Showing volume across all workouts." : "Showing volume for \"\(volumeWorkoutName!)\" only.")
                            .font(.caption)
                    }

                    Section {
                        // Exercise filter — pick from exercises that have been logged
                        let loggedExercises: [Exercise] = {
                            let loggedIDs = Set(logState.logs.flatMap { $0.exercises }.map { $0.exerciseID })
                            return exercisesState.exercises
                                .filter { loggedIDs.contains($0.id) }
                                .sorted { $0.name < $1.name }
                        }()
                        if loggedExercises.isEmpty {
                            Text("No exercises logged yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: { volumeExerciseID = nil }) {
                                HStack {
                                    Text("All Exercises")
                                    Spacer()
                                    if volumeExerciseID == nil {
                                        Image(systemName: "checkmark").foregroundColor(.primary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            ForEach(loggedExercises) { exercise in
                                Button(action: {
                                    volumeExerciseID = (volumeExerciseID == exercise.id) ? nil : exercise.id
                                }) {
                                    HStack {
                                        Text(exercise.name)
                                        Spacer()
                                        if volumeExerciseID == exercise.id {
                                            Image(systemName: "checkmark").foregroundColor(.primary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Filter by Exercise")
                    } footer: {
                        Text(volumeExerciseID == nil ? "Showing volume across all exercises." : "Showing volume for selected exercise only.")
                            .font(.caption)
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            VStack {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .frame(maxWidth: .infinity, maxHeight: 50)
                                        .background(selectedIcon == icon ? Color.primary.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(8)
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Tile")
            .onAppear {
                title = tile.title
                selectedIcon = tile.icon
                selectedSize = tile.size
                oneRMExerciseIDs = tile.oneRMExerciseIDs
                personalRecordExerciseIDs = tile.personalRecordExerciseIDs
                volumeWorkoutName = tile.volumeWorkoutName
                volumeExerciseID = tile.volumeExerciseID
            }
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updatedTile = tile
                        updatedTile.title = title
                        updatedTile.icon = selectedIcon
                        updatedTile.size = selectedSize
                        updatedTile.oneRMExerciseIDs = oneRMExerciseIDs
                        updatedTile.personalRecordExerciseIDs = personalRecordExerciseIDs
                        updatedTile.volumeWorkoutName = volumeWorkoutName
                        updatedTile.volumeExerciseID = volumeExerciseID
                        onSave(updatedTile)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}

// MARK: - Stat Card Tile View

private struct StatCardTileView: View {
    let title: String
    let icon: String
    let value: String
    let statType: StatCardType
    let frequencyDays: [WeekdayFrequency]
    let frequencyRangeLabel: String
    let muscleSegments: [PieSegment]
    let accentPlacement: AccentPlacement
    let accentColor: Color
    let tileTint: Color?
    var defaultBackground: Color? = nil
    var borderColor: Color? = nil
    let trend: (symbol: String, color: Color)?
    let personalRecordLabel: String?   // exercise name for PR card (legacy single-value path)
    var oneRMEntries: [(name: String, value: Double)] = []
    var personalRecordEntries: [(name: String, value: Double)] = []
    var volumeWeeks: [(label: String, volume: Double)] = []
    var dayOfWeekCounts: [(label: String, count: Int)] = []

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var iPad: Bool { sizeClass == .regular }

    var body: some View {
        let bg = tileTint ?? defaultBackground ?? Color(UIColor.secondarySystemBackground)
        let tileBorder: Color = tileTint != nil ? .clear : (borderColor ?? .clear)
        ZStack(alignment: .leading) {
            VStack(spacing: 6) {
                // Header row: icon + title
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: iPad ? 22 : 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .fixedSize()
                    Text(title)
                        .font(.system(size: iPad ? 17 : 11, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer().frame(height: 4)

                // Data / Content
                if statType == .workoutFrequency {
                    VStack(spacing: 6) {
                        WeekFrequencyView(days: frequencyDays)
                        Text(frequencyRangeLabel)
                            .font(.system(size: iPad ? 16 : 10))
                            .foregroundColor(.gray)
                    }
                } else if statType == .oneRepMax {
                    if oneRMEntries.isEmpty {
                        VStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "trophy")
                                .font(.system(size: iPad ? 35 : 22, weight: .light))
                                .foregroundColor(.gray)
                            Text("Log sets with 3–10 reps\nto see your 1RM estimates")
                                .font(.system(size: iPad ? 16 : 10))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        let best = oneRMEntries.map { $0.value }.max() ?? 1
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(oneRMEntries.prefix(10).enumerated()), id: \.offset) { index, entry in
                                HStack(spacing: 6) {
                                    // Rank badge
                                    Text("#\(index + 1)")
                                        .font(.system(size: iPad ? 16 : 10, weight: .bold, design: .rounded))
                                        .foregroundColor(index == 0 ? .yellow : .gray)
                                        .frame(width: iPad ? 32 : 20)
                                    // Exercise name
                                    Text(entry.name)
                                        .font(.system(size: iPad ? 16 : 10))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    // 1RM value
                                    Text(String(format: "%.0f", entry.value))
                                        .font(.system(size: iPad ? 16 : 10, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                // Mini progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.primary.opacity(0.08))
                                            .frame(height: 3)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(index == 0 ? Color.yellow : Color.primary.opacity(0.35))
                                            .frame(width: geo.size.width * CGFloat(entry.value / best), height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if statType == .personalRecord {
                    if personalRecordEntries.isEmpty {
                        VStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "star")
                                .font(.system(size: iPad ? 35 : 22, weight: .light))
                                .foregroundColor(.gray)
                            Text("Log sets with weights\nto see your records")
                                .font(.system(size: iPad ? 16 : 10))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        let best = personalRecordEntries.map { $0.value }.max() ?? 1
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(personalRecordEntries.prefix(10).enumerated()), id: \.offset) { index, entry in
                                HStack(spacing: 6) {
                                    Text("#\(index + 1)")
                                        .font(.system(size: iPad ? 16 : 10, weight: .bold, design: .rounded))
                                        .foregroundColor(index == 0 ? Color(red: 1, green: 0.8, blue: 0) : .gray)
                                        .frame(width: iPad ? 32 : 20)
                                    Text(entry.name)
                                        .font(.system(size: iPad ? 16 : 10))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(format: "%.0f", entry.value))
                                        .font(.system(size: iPad ? 16 : 10, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.primary.opacity(0.08))
                                            .frame(height: 3)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(index == 0 ? Color(red: 1, green: 0.8, blue: 0) : Color.primary.opacity(0.35))
                                            .frame(width: geo.size.width * CGFloat(entry.value / best), height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if statType == .muscleGroupDistribution {
                    GeometryReader { geometry in
                        let maxHeight = geometry.size.height
                        let maxWidth  = geometry.size.width
                        let pieSize   = min(maxHeight * 0.9, maxWidth * 0.55)

                        if muscleSegments.isEmpty {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    ZStack {
                                        PieChartView(segments: [PieSegment(label: "No Data", value: 1.0, color: .gray)])
                                        Text("No workouts\nlogged")
                                            .font(.system(size: iPad ? 16 : 10, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(width: pieSize, height: pieSize)
                                    Spacer()
                                }
                                Spacer()
                            }
                        } else {
                            ZStack {
                                HStack(spacing: 12) {
                                    PieChartView(segments: muscleSegments)
                                        .frame(width: pieSize, height: pieSize)
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(muscleSegments, id: \.label) { segment in
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(segment.color)
                                                    .frame(width: 6, height: 6)
                                                Text(segment.label)
                                                    .font(.system(size: iPad ? 16 : 10))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.75)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                } else if statType == .volumeThisWeek {
                    if volumeWeeks.isEmpty || volumeWeeks.allSatisfy({ $0.volume == 0 }) {
                        VStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "chart.bar")
                                .font(.system(size: iPad ? 35 : 22, weight: .light))
                                .foregroundColor(.gray)
                            Text("No volume logged yet")
                                .font(.system(size: iPad ? 16 : 10))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VolumeBarChartView(weeks: volumeWeeks)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if statType == .favoriteDay {
                    if dayOfWeekCounts.allSatisfy({ $0.count == 0 }) {
                        VStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "calendar")
                                .font(.system(size: iPad ? 35 : 22, weight: .light))
                                .foregroundColor(.gray)
                            Text("No workouts logged yet")
                                .font(.system(size: iPad ? 16 : 10))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        DayOfWeekBarChartView(days: dayOfWeekCounts)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    let isNumeric = statType == .totalWorkouts || statType == .dayStreaks
                        || statType == .totalTime
                        || statType == .longestStreak || statType == .restDays
                    Text(value)
                        .font(.system(size: isNumeric ? (iPad ? 44 : 28) : (iPad ? 25 : 16), weight: .bold, design: isNumeric ? .rounded : .default))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)

                    // Trend arrow below the main value
                    if let t = trend {
                        Text(t.symbol)
                            .font(.system(size: iPad ? 20 : 13, weight: .bold))
                            .foregroundColor(t.color)
                    }

                    // Secondary label for Personal Record card
                    if statType == .personalRecord, let exercise = personalRecordLabel {
                        Text(exercise)
                            .font(.system(size: iPad ? 16 : 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tileBorder, lineWidth: 1))

            // Accent bar
            if accentPlacement != .none {
                AccentBarView(placement: accentPlacement, color: accentColor)
            }
        }
    }
}

/// A colored accent bar along one edge of the tile
private struct AccentBarView: View {
    let placement: AccentPlacement
    let color: Color

    private let thickness: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            switch placement {
            case .none: EmptyView()
            case .left:
                Rectangle()
                    .fill(color)
                    .frame(width: thickness, height: geo.size.height - 16)
                    .clipShape(RoundedRectangle(cornerRadius: thickness / 2))
                    .position(x: thickness / 2 + 4, y: geo.size.height / 2)
            case .right:
                Rectangle()
                    .fill(color)
                    .frame(width: thickness, height: geo.size.height - 16)
                    .clipShape(RoundedRectangle(cornerRadius: thickness / 2))
                    .position(x: geo.size.width - thickness / 2 - 4, y: geo.size.height / 2)
            case .top:
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width - 16, height: thickness)
                    .clipShape(RoundedRectangle(cornerRadius: thickness / 2))
                    .position(x: geo.size.width / 2, y: thickness / 2 + 4)
            case .bottom:
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width - 16, height: thickness)
                    .clipShape(RoundedRectangle(cornerRadius: thickness / 2))
                    .position(x: geo.size.width / 2, y: geo.size.height - thickness / 2 - 4)
            }
        }
    }
}

private struct WeekFrequencyView: View {
    let days: [WeekdayFrequency]

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let iPad = sizeClass == .regular
        HStack(spacing: iPad ? 8 : 4) {
            ForEach(days) { day in
                VStack(spacing: iPad ? 8 : 4) {
                    Text(day.label)
                        .font(.system(size: iPad ? 14 : 9, weight: .medium))
                        .foregroundColor(.gray)

                    if day.hasWorkout {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: iPad ? 22 : 14))
                    } else {
                        Circle()
                            .stroke(Color.gray.opacity(0.55), lineWidth: 1.5)
                            .frame(width: iPad ? 22 : 14, height: iPad ? 22 : 14)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(iPad ? 10 : 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Volume Bar Chart (weekly, past 6 weeks)

private struct VolumeTrendLine: View {
    let fractions: [Double]
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let barAreaH: CGFloat
    let labelH: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let baseline: CGFloat = size.height - labelH - 3
            let allXs: [CGFloat] = fractions.indices.map { i in
                barWidth / 2 + CGFloat(i) * (barWidth + barSpacing)
            }
            let pts: [CGPoint] = fractions.indices.map { i in
                if fractions[i] > 0 {
                    let clamped: CGFloat = max(18.0 / barAreaH, CGFloat(fractions[i]))
                    return CGPoint(x: allXs[i], y: baseline - clamped * barAreaH)
                } else {
                    return CGPoint(x: allXs[i], y: baseline)
                }
            }
            guard pts.count > 1 else { return }

            var path = Path()
            path.move(to: pts[0])
            for i in 0 ..< pts.count - 1 {
                let p0 = pts[max(i - 1, 0)]
                let p1 = pts[i]
                let p2 = pts[min(i + 1, pts.count - 1)]
                let p3 = pts[min(i + 2, pts.count - 1)]
                let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                                  y: min(baseline, p1.y + (p2.y - p0.y) / 6))
                let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                                  y: min(baseline, p2.y - (p3.y - p1.y) / 6))
                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
            ctx.stroke(path, with: .color(Color.blue.opacity(0.15)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            ctx.stroke(path, with: .color(Color.blue.opacity(0.65)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            for (i, pt) in pts.enumerated() {
                guard fractions[i] > 0 else { continue }
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
                         with: .color(Color.blue.opacity(0.75)))
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 1.5, y: pt.y - 1.5, width: 3, height: 3)),
                         with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct VolumeBarChartView: View {
    let weeks: [(label: String, volume: Double)]

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let iPad = sizeClass == .regular
        let barAreaH: CGFloat = iPad ? 160 : 90
        let labelH: CGFloat = iPad ? 22 : 14
        let barSpacing: CGFloat = iPad ? 10 : 6
        let maxVol = weeks.map { $0.volume }.max() ?? 1
        let currentWeekIdx = weeks.count - 1
        let fractions: [Double] = weeks.map { maxVol > 0 ? $0.volume / maxVol : 0 }

        VStack(alignment: .leading, spacing: 4) {
            // Bar area with trend line overlaid
            GeometryReader { geo in
                let barWidth = (geo.size.width - barSpacing * CGFloat(weeks.count - 1)) / CGFloat(weeks.count)
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                            let fraction = CGFloat(fractions[idx])
                            let barHeight = week.volume > 0 ? max(iPad ? 28 : 18, barAreaH * fraction) : 0
                            let isCurrentWeek = idx == currentWeekIdx
                            VStack(spacing: 3) {
                                ZStack {
                                    if week.volume > 0 {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(isCurrentWeek ? Color.primary : Color.primary.opacity(0.35))
                                            .frame(height: barHeight)
                                        let volLabel = week.volume >= 1000
                                            ? String(format: "%.1fk", week.volume / 1000)
                                            : String(format: "%.0f", week.volume)
                                        Text(volLabel)
                                            .font(.system(size: iPad ? 17 : 11, weight: .bold))
                                            .foregroundColor(isCurrentWeek ? Color(UIColor.systemBackground) : Color.primary.opacity(0.7))
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(height: barHeight)
                                Text(week.label)
                                    .font(.system(size: iPad ? 15 : 10))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: labelH)
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VolumeTrendLine(
                        fractions: fractions,
                        barWidth: barWidth,
                        barSpacing: barSpacing,
                        barAreaH: barAreaH,
                        labelH: labelH
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: iPad ? 185 : 107)

            // % vs last week
            if weeks.count >= 2 {
                let prev = weeks[weeks.count - 2].volume
                let curr = weeks[weeks.count - 1].volume
                if prev > 0 {
                    let pct = Int(((curr - prev) / prev) * 100)
                    HStack {
                        Spacer()
                        Image(systemName: pct >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: iPad ? 14 : 9, weight: .bold))
                            .foregroundColor(pct >= 0 ? .green : .red)
                        Text("\(abs(pct))% vs last week")
                            .font(.system(size: iPad ? 14 : 9))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day of Week Bar Chart (horizontal)

private struct DayOfWeekBarChartView: View {
    let days: [(label: String, count: Int)]

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let iPad = sizeClass == .regular
        let sorted = days.sorted { $0.count > $1.count }
        let maxCount = sorted.map { $0.count }.max() ?? 1

        VStack(alignment: .leading, spacing: iPad ? 10 : 5) {
            ForEach(Array(sorted.enumerated()), id: \.offset) { idx, day in
                let fraction = maxCount > 0 ? CGFloat(day.count) / CGFloat(maxCount) : 0
                HStack(spacing: iPad ? 10 : 6) {
                    Text(String(day.label.prefix(3)))
                        .font(.system(size: iPad ? 15 : 9, weight: idx == 0 ? .bold : .semibold))
                        .foregroundColor(idx == 0 ? .primary : .gray)
                        .frame(width: iPad ? 42 : 26, alignment: .leading)
                    GeometryReader { barGeo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: iPad ? 18 : 10)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(idx == 0 ? Color.primary : Color.primary.opacity(0.3))
                                .frame(width: barGeo.size.width * fraction, height: iPad ? 18 : 10)
                        }
                    }
                    .frame(height: iPad ? 18 : 10)
                    Text("\(day.count)")
                        .font(.system(size: iPad ? 15 : 9, weight: .bold))
                        .foregroundColor(idx == 0 ? .primary : .gray)
                        .frame(width: iPad ? 28 : 18, alignment: .trailing)
                }
                .frame(height: iPad ? 24 : 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DonutSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: center, radius: outerRadius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius,
                    startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

private struct DonutSeparatorShape: Shape {
    let angle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cosA = CGFloat(Foundation.cos(angle.radians))
        let sinA = CGFloat(Foundation.sin(angle.radians))
        path.move(to: CGPoint(x: center.x + innerRadius * cosA, y: center.y + innerRadius * sinA))
        path.addLine(to: CGPoint(x: center.x + outerRadius * cosA, y: center.y + outerRadius * sinA))
        return path
    }
}

private struct PieChartView: View {
    let segments: [PieSegment]

    private var isDummyChart: Bool {
        segments.count == 1 && segments[0].value == 1.0 && segments[0].color == .gray
    }

    var body: some View {
        GeometryReader { geometry in
            PieChartCanvas(
                segments: segments,
                isDummyChart: isDummyChart,
                size: geometry.size
            )
        }
    }

    private func angleStart(at index: Int) -> Angle {
        let total = segments.map { $0.value }.reduce(0, +)
        let prior = segments.prefix(index).map { $0.value }.reduce(0, +)
        return .degrees((prior / total) * 360 - 90)
    }

    private func angleEnd(at index: Int) -> Angle {
        let total = segments.map { $0.value }.reduce(0, +)
        let current = segments.prefix(index + 1).map { $0.value }.reduce(0, +)
        return .degrees((current / total) * 360 - 90)
    }
}

private struct PieChartCanvas: View {
    let segments: [PieSegment]
    let isDummyChart: Bool
    let size: CGSize

    private var outerRadius: CGFloat { min(size.width, size.height) / 2 }
    private var innerRadius: CGFloat { outerRadius * 0.34 }
    private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    var body: some View {
        ZStack {
            ForEach(segments.indices, id: \.self) { index in
                DonutSegmentShape(
                    startAngle: angleStart(at: index),
                    endAngle: angleEnd(at: index),
                    outerRadius: outerRadius,
                    innerRadius: innerRadius,
                    center: center
                )
                .fill(segments[index].color)

                if segments.count > 1 {
                    DonutSeparatorShape(
                        angle: angleStart(at: index),
                        innerRadius: innerRadius,
                        outerRadius: outerRadius,
                        center: center
                    )
                    .stroke(Color.white, lineWidth: 1.5)
                }

                // Percentage label in the middle of the ring arc — only for segments ≥ 8%
                if !isDummyChart {
                    percentageLabel(at: index)
                }
            }

            // Center hole
            Circle()
                .fill(Color(uiColor: .systemGray6))
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .position(center)
        }
    }

    @ViewBuilder
    private func percentageLabel(at index: Int) -> some View {
        let total = segments.map { $0.value }.reduce(0, +)
        let fraction = total > 0 ? segments[index].value / total : 0
        // Only show label when segment is large enough to fit text
        if fraction >= 0.08 {
            let start = angleStart(at: index)
            let end = angleEnd(at: index)
            let midAngle = Angle.degrees((start.degrees + end.degrees) / 2)
            // Position label in the middle of the ring band
            let labelRadius = (innerRadius + outerRadius) / 2
            let cosA = CGFloat(Foundation.cos(midAngle.radians))
            let sinA = CGFloat(Foundation.sin(midAngle.radians))
            let labelX = center.x + labelRadius * cosA
            let labelY = center.y + labelRadius * sinA

            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: max(8, outerRadius * 0.16), weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 0)
                .position(x: labelX, y: labelY)
        }
    }

    private func angleStart(at index: Int) -> Angle {
        let total = segments.map { $0.value }.reduce(0, +)
        let prior = segments.prefix(index).map { $0.value }.reduce(0, +)
        return .degrees((prior / total) * 360 - 90)
    }

    private func angleEnd(at index: Int) -> Angle {
        let total = segments.map { $0.value }.reduce(0, +)
        let current = segments.prefix(index + 1).map { $0.value }.reduce(0, +)
        return .degrees((current / total) * 360 - 90)
    }
}

private struct WeekdayFrequency: Identifiable {
    let id = UUID()
    let label: String
    let hasWorkout: Bool
}

private struct PieSegment {
    let label: String
    let value: Double
    let color: Color
}

private extension DateFormatter {
    static func weekdayInitial(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        let text = formatter.string(from: date)
        return String(text.prefix(1))
    }
}

// MARK: - Walking Dog View

private struct WalkingDogView: View {
    let position: CGPoint
    let legPhase: Double // 0-1 for leg animation phase
    let screenSize: CGSize
    let scale: CGFloat = 1.5
    
    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: 4 * scale)
                .fill(Color.black)
                .frame(width: 12 * scale, height: 8 * scale)
            
            // Head
            Circle()
                .fill(Color.black)
                .frame(width: 6 * scale, height: 6 * scale)
                .offset(x: 7 * scale, y: -2 * scale)
            
            // Ears
            Circle()
                .fill(Color.black)
                .frame(width: 2 * scale, height: 3 * scale)
                .offset(x: 9 * scale, y: -5 * scale)
            
            Circle()
                .fill(Color.black)
                .frame(width: 2 * scale, height: 3 * scale)
                .offset(x: 6 * scale, y: -5 * scale)
            
            // Tail
            RoundedRectangle(cornerRadius: 1 * scale)
                .fill(Color.black)
                .frame(width: 2 * scale, height: 6 * scale)
                .offset(x: -7 * scale, y: -1 * scale)
                .rotationEffect(.degrees(Double(legPhase) * 30 - 15))
            
            // Front legs (left and right)
            VStack(spacing: 4 * scale) {
                // Left front leg
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2 * scale, height: 6 * scale)
                    .offset(y: 4 * scale)
                    .rotationEffect(.degrees(legPhase > 0.5 ? -25 : 25), anchor: .top)
                
                // Right front leg
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2 * scale, height: 6 * scale)
                    .offset(y: 4 * scale)
                    .rotationEffect(.degrees(legPhase > 0.5 ? 25 : -25), anchor: .top)
            }
            .offset(x: 3 * scale, y: 0)
            
            // Back legs (left and right)
            VStack(spacing: 4 * scale) {
                // Left back leg
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2 * scale, height: 6 * scale)
                    .offset(y: 4 * scale)
                    .rotationEffect(.degrees(legPhase > 0.5 ? 25 : -25), anchor: .top)
                
                // Right back leg
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2 * scale, height: 6 * scale)
                    .offset(y: 4 * scale)
                    .rotationEffect(.degrees(legPhase > 0.5 ? -25 : 25), anchor: .top)
            }
            .offset(x: -3 * scale, y: 0)
        }
        .position(position)
    }
}

// MARK: - Today's Plan Tile View

private struct TodaysPlanTileView: View {
    @Environment(TrainingPlanState.self) private var planState
    @Environment(WorkoutsState.self) private var workoutsState
    @Environment(ExercisesState.self) private var exercisesState
    @Environment(VoiceTrainerState.self) private var voiceTrainerState
    @Environment(TimerState.self) private var timerState

    var tileTint: Color?
    var defaultBackground: Color? = nil
    var borderColor: Color? = nil
    var accentPlacement: AccentPlacement
    var accentColor: Color
    var onLaunch: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var iPad: Bool { sizeClass == .regular }

    private var planDay: PlanDay? {
        planState.planDay(for: Calendar.current.startOfDay(for: Date()))
    }

    var body: some View {
        let bg = tileTint ?? defaultBackground ?? Color(UIColor.secondarySystemBackground)
        let tileBorder: Color = tileTint != nil ? .clear : (borderColor ?? .clear)
        ZStack(alignment: .leading) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onLaunch()
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: iPad ? 22 : 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .fixedSize()
                        Text("Today's Plan")
                            .font(.system(size: iPad ? 17 : 11, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer().frame(height: 2)

                    if let pd = planDay, !pd.isEmpty {
                        let entries = planItems(pd)
                        ForEach(entries, id: \.name) { entry in
                            HStack(spacing: 4) {
                                Image(systemName: entry.icon)
                                    .font(.system(size: iPad ? 16 : 10))
                                    .foregroundColor(.secondary)
                                Text(entry.name)
                                    .font(.system(size: iPad ? 16 : 10))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                if entry.completed {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: iPad ? 16 : 10))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    } else {
                        Text("Rest day")
                            .font(.system(size: iPad ? 16 : 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tileBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if accentPlacement != .none {
                AccentBarView(placement: accentPlacement, color: accentColor)
            }
        }
    }

    private struct PlanItem {
        let name: String
        let icon: String
        let completed: Bool
    }

    private var todayCompletedLogNames: Set<String> {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let logs = WorkoutLogState.shared.logs.filter { cal.isDate($0.completedAt, inSameDayAs: today) }
        return Set(logs.map { $0.workoutName })
    }

    private func planItems(_ pd: PlanDay) -> [PlanItem] {
        let completed = todayCompletedLogNames
        var items: [PlanItem] = []
        items += pd.workoutIDs.compactMap { id in
            workoutsState.workouts.first { $0.id == id }.map {
                PlanItem(name: $0.name, icon: "dumbbell.fill", completed: completed.contains($0.name))
            }
        }
        items += pd.exerciseIDs.compactMap { id in
            exercisesState.exercises.first { $0.id == id }.map {
                PlanItem(name: $0.name, icon: "figure.strengthtraining.traditional", completed: completed.contains("\($0.name)"))
            }
        }
        items += pd.voiceActivityIDs.compactMap { id in
            voiceTrainerState.savedConfigurations.first { $0.id == id }.map {
                PlanItem(name: $0.name, icon: "waveform", completed: completed.contains("Trainer – \($0.name)"))
            }
        }
        items += pd.timerIDs.compactMap { id in
            timerState.configs.first { $0.id == id }.map { c in
                let displayName = c.name.isEmpty ? c.type.rawValue : c.name
                return PlanItem(name: displayName, icon: c.type.iconName, completed: completed.contains("\(c.type.rawValue) – \(displayName)"))
            }
        }
        return items
    }
}

#Preview {
    DashboardModuleView(module: DashboardModule())
}
