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
    @AppStorage("distanceUnit") private var distanceUnit: String = "mi"
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
    @Environment(WaterState.self) var waterState
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
    @State private var animatingTiles: Set<UUID> = []         // blocks interaction while spinning
    @State private var windUpDegrees: [UUID: Double] = [:]    // accumulated CCW wind-up (positive = wound up)
    @State private var lastDragAngle: [UUID: Double] = [:]    // previous drag angle for delta calc
    @State private var flyingTiles: Set<UUID> = []
    @State private var tileOffsets: [UUID: (x: CGFloat, y: CGFloat)] = [:]
    @State private var tileRotations: [UUID: Double] = [:]
    @State private var showBlankAlert = false
    @State private var blankAlertMessage = ""
    @State private var showingSettings = false
    
    // Track game levels for reactive UI updates
    @State private var matchGameLevel: Int = 1
    @State private var refreshTrigger: UUID = UUID()

    // Detail sheets opened by tapping a stat tile.
    @State private var statDetail: StatDetailSheet? = nil

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
            TodaysPlanModuleView(showDoneButton: true)
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
        .fullScreenCover(item: $statDetail) { detail in
            statDetailDestination(for: detail)
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
        // PERFORMANCE FIX: Only calculate these for the specific tiles that need them
        let prEntries: [(name: String, value: Double, date: Date?)] = tile.statCardType == .personalRecord ? personalRecordEntries(for: tile) : []
        let rmEntries: [(name: String, value: Double, date: Date?)] = tile.statCardType == .oneRepMax ? oneRMEntries(for: tile) : []
        let topDurationEntries: [(name: String, value: Double, date: Date)] = tile.statCardType == .topDurations ? topDurationEntries(for: tile) : []
        let topDistanceEntries: [(name: String, value: Double, date: Date)] = tile.statCardType == .topDistances ? topDistanceEntries(for: tile) : []
        // PR, 1RM, leaderboard, and todaysPlan tiles use content-driven height (nil) so layout flows naturally
        let dynamicEntryCount: Int = tile.statCardType == .personalRecord ? 1
            : tile.statCardType == .oneRepMax ? 1
            : tile.statCardType == .topDurations ? 1
            : tile.statCardType == .topDistances ? 1
            : tile.statCardType == .todaysPlan ? 1
            : 0
        let isIPad = sizeClass == .regular
        // favoriteDay: header(44) + 7 rows × 19pt each + bottom padding(12) ≈ 189
        // favoriteExercise: header + up-to-5 leaderboard rows — same shape, but
        // capped at 5 so there's no empty space below the last row.
        // volumeThisWeek: header(44) + bars(107) + trend(20) + padding(16) ≈ 187
        let tileHeight: CGFloat?
        if isDoubleHeight {
            tileHeight = isIPad ? columnWidth * 1.3 + spacing : columnWidth * 2 + spacing
        } else if tile.statCardType == .favoriteDay {
            tileHeight = CGFloat(44 + 7 * 19 + 12) * (isIPad ? 1.6 : 1.0)
        } else if tile.statCardType == .favoriteExercise {
            tileHeight = CGFloat(44 + 5 * 19 + 12) * (isIPad ? 1.6 : 1.0)
        } else if tile.statCardType == .volumeThisWeek {
            tileHeight = CGFloat(44 + 107 + 20 + 16) * (isIPad ? 1.6 : 1.0)
        } else if tile.statCardType == .waterIntake14Days {
            tileHeight = CGFloat(44 + 93 + 20 + 16) * (isIPad ? 1.6 : 1.0)
        } else if tile.statCardType == .workoutFrequency {
            // Let it calculate height from content naturally
            tileHeight = nil
        } else {
            tileHeight = columnWidth
        }
        
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
                // PERFORMANCE FIX: Only calculate data for the specific stat type this tile needs
                StatCardTileView(
                    title: tile.title,
                    icon: tile.icon,
                    value: statValue(for: statCard),
                    statType: statCard,
                    frequencyDays: statCard == .workoutFrequency ? workoutFrequencyDays() : [],
                    frequencyRangeLabel: statCard == .workoutFrequency ? workoutFrequencyRangeLabel() : "",
                    muscleSegments: statCard == .muscleGroupDistribution ? muscleDistributionSegments() : [],
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
                    dayOfWeekCounts: statCard == .favoriteDay ? logState.workoutCountByDayOfWeek : [],
                    favoriteExerciseEntries: statCard == .favoriteExercise ? topFavoriteExerciseEntries() : [],
                    waterDailyTotals: statCard == .waterIntake14Days ? waterState.dailyTotals(days: 14) : [],
                    waterGoalOz: waterState.dailyGoalOz,
                    waterUnit: waterState.unit,
                    waterStreak: statCard == .waterIntake14Days ? waterState.currentStreak : 0,
                    longestStreak: statCard == .workoutFrequency ? logState.longestStreak : 0,
                    currentStreak: statCard == .workoutFrequency ? logState.currentStreak : 0,
                    topDurationEntries: topDurationEntries,
                    topDistanceEntries: topDistanceEntries,
                    distanceUnit: distanceUnit
                )
                .frame(width: tileWidth, height: (dynamicEntryCount > 0 || tileHeight == nil) ? nil : tileHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleStatTileTap(statCard: statCard, tile: tile)
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
            } else {
                interactiveTileView(tile: tile, width: tileWidth, height: tileHeight ?? columnWidth)
            }
        }
    }
    
    private func interactiveTileView(tile: DashboardTile, width: CGFloat, height: CGFloat) -> some View {
        let bg: Color = tile.tileTintColor ?? state.dashboardTileBackgroundColor ?? Color(UIColor.secondarySystemBackground)
        let tileBorder: Color = tile.tileTintColor != nil ? .clear : (state.dashboardTileBorderColor ?? .clear)
        let isThreePieceShortcut = tile.tileType == .shortcut &&
            (tile.shortcutType == .workout || tile.shortcutType == .timer ||
             tile.shortcutType == .voiceTrainer || tile.shortcutType == .quickExercise)

        let isIPadLayout = sizeClass == .regular
        let bottomBarHeight: CGFloat = isIPadLayout ? max(height * 0.28, 52) : 32
        let iconSize: CGFloat = isIPadLayout ? 28 : 18
        let bottomIconSize: CGFloat = isIPadLayout ? 18 : 13

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
                                    .font(.system(size: iconSize, weight: .semibold))
                                    .foregroundColor(.primary)
                                if !tile.title.isEmpty {
                                    Text(tile.title)
                                        .font(isIPadLayout ? .subheadline : .caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: height - bottomBarHeight - 1)
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
                                    .font(.system(size: bottomIconSize))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: bottomBarHeight)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .frame(width: 1)
                                .frame(height: bottomBarHeight * 0.6)
                                .overlay(
                                    Rectangle()
                                        .fill(Color(UIColor.separator))
                                        .frame(width: 1)
                                )

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
                                    .font(.system(size: bottomIconSize))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: bottomBarHeight)
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
                let isBlank = isBlankTile(tile)
                let isSpinning = animatingTiles.contains(tile.id)
                ZStack(alignment: .leading) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        Image(systemName: tile.icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.primary)
                            .rotationEffect(.degrees(spinningTiles[tile.id] ?? 0))
                            .animation(.easeOut(duration: 2.5), value: spinningTiles[tile.id])

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
                        } else if isBlank, let count = dashboardState.tileClickCounts[tile.id], count > 0 {
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
                .contentShape(Rectangle())
                .modifier(BlankTileGestureModifier(
                    tile: tile,
                    isBlank: isBlank,
                    isSpinning: isSpinning,
                    windUpDegrees: $windUpDegrees,
                    lastDragAngle: $lastDragAngle,
                    spinningTiles: $spinningTiles,
                    onRelease: { wound in handleBlankTileAction(tile, windUpDegrees: wound) },
                    onTap: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if let targetID = findModuleID(for: tile) { state.selectModule(targetID) }
                    }
                ))
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
                .frame(width: 44, height: 44)  // Increase tap target to 44x44 (Apple HIG minimum)
                .contentShape(Rectangle())      // Make entire frame tappable
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

    /// Routes a tap on a stat card to either a related module (water) or a
    /// full-screen detail sheet (leaderboards, volume, muscle groups).
    private func handleStatTileTap(statCard: StatCardType, tile: DashboardTile) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch statCard {
        case .waterIntake14Days:
            state.selectModule(ModuleIDs.water)
        case .personalRecord:
            statDetail = .personalRecord(tile)
        case .oneRepMax:
            statDetail = .oneRepMax(tile)
        case .topDurations:
            statDetail = .topDurations(tile)
        case .topDistances:
            statDetail = .topDistances(tile)
        case .favoriteExercise:
            statDetail = .favoriteExercise(tile)
        case .volumeThisWeek:
            statDetail = .volume(tile)
        case .muscleGroupDistribution:
            statDetail = .muscleGroups(tile)
        default:
            break
        }
    }
    
    private func handleBlankTileAction(_ tile: DashboardTile, windUpDegrees: Double = 0) {
        // Increment click counter using persisted state
        dashboardState.incrementClickCount(for: tile.id)
        
        switch tile.blankAction ?? .animation1 {
        case .animation1:
            // Simple tap = small random spin. Wound up = spin proportional to wind-up.
            let forwardDegrees: Double
            let duration: Double
            if windUpDegrees > 10 {
                // Release wound-up energy: spin forward the wound amount + extra momentum
                forwardDegrees = windUpDegrees * 3.0 + Double.random(in: 0...180)
                duration = 1.0 + (windUpDegrees / 360) * 0.4
            } else {
                // Simple tap
                forwardDegrees = Double.random(in: 2...4) * 360
                duration = 1.5
            }
            animatingTiles.insert(tile.id)
            withAnimation(.easeOut(duration: duration)) {
                spinningTiles[tile.id, default: 0] += forwardDegrees
            }
            // Unblock after animation completes
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                animatingTiles.remove(tile.id)
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
        case .favoriteExercise, .favoriteDay:
            // Both render their own leaderboard list — no text value needed.
            return ""
        case .workoutFrequency:
            // Card renders its own dot grid + streak rows.
            return ""
        case .muscleGroupDistribution:
            let segments = muscleDistributionSegments()
            return segments.first?.label ?? "—"
        case .volumeThisWeek:
            let v = logState.volumeThisWeek
            if v >= 1000 {
                return String(format: "%.1fk", v / 1000)
            }
            return String(format: "%.0f", v)
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
        case .waterIntake14Days:
            let oz = waterState.todayOz
            let display = waterState.unit.fromOz(oz)
            return String(format: "%.0f %@", display, waterState.unit.rawValue)
        case .topDurations, .topDistances:
            // Value not shown as text; tile renders its own leaderboard list
            return ""
        }
    }

    /// Returns an optional trend arrow (↑ / ↓) and color for stats that support comparison
    private func trendInfo(for stat: StatCardType) -> (symbol: String, color: Color)? {
        switch stat {
        case .volumeThisWeek:
            let this = logState.volumeThisWeek
            let last = logState.volumeLastWeek
            if last == 0 { return nil }
            return this > last ? ("↑", .green) : this < last ? ("↓", .red) : nil
        case .waterIntake14Days:
            let today = waterState.todayOz
            let yesterday = waterState.totalOzForDate(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            if yesterday == 0 { return nil }
            return today > yesterday ? ("↑", .green) : today < yesterday ? ("↓", .red) : nil
        default:
            return nil
        }
    }

    private func personalRecordEntries(for tile: DashboardTile) -> [(name: String, value: Double, date: Date?)] {
        let exerciseIDs: [UUID] = {
            if let ids = tile.personalRecordExerciseIDs, !ids.isEmpty { return ids }
            return logState.topExercisesByWeight(limit: 5).map { $0.exerciseID }
        }()
        let rows: [(name: String, value: Double, date: Date?)] = exerciseIDs.compactMap { id in
            // Walk every log and find the single set with the heaviest weight
            // for this exercise, plus the log it came from (to surface its date
            // alongside the value — matches the Top Durations row layout).
            var best: (name: String, value: Double, date: Date)? = nil
            for log in logState.logs {
                for ex in log.exercises where ex.exerciseID == id {
                    for s in ex.sets where s.weight > 0 {
                        if best == nil || s.weight > best!.value {
                            best = (ex.exerciseName, s.weight, log.completedAt)
                        }
                    }
                }
            }
            guard let b = best else { return nil }
            return (name: b.name, value: b.value, date: b.date)
        }
        // Stable order: value desc, then newest date first, then name asc — so
        // ties don't reshuffle when the view re-renders.
        return rows.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            let l = lhs.date ?? .distantPast
            let r = rhs.date ?? .distantPast
            if l != r { return l > r }
            return lhs.name < rhs.name
        }
    }

    private func oneRMEntries(for tile: DashboardTile) -> [(name: String, value: Double, date: Date?)] {
        let exerciseIDs: [UUID] = {
            if let ids = tile.oneRMExerciseIDs, !ids.isEmpty { return ids }
            return logState.topExercisesBy1RM(limit: 5).map { $0.exerciseID }
        }()
        let rows: [(name: String, value: Double, date: Date?)] = exerciseIDs.compactMap { id in
            // Walk every log and find the set with the highest Epley-estimated
            // 1RM for this exercise, plus the log date.
            var best: (name: String, value: Double, date: Date)? = nil
            for log in logState.logs {
                for ex in log.exercises where ex.exerciseID == id {
                    for s in ex.sets {
                        let v = Self.epley(weight: s.weight, reps: s.reps)
                        guard v > 0 else { continue }
                        if best == nil || v > best!.value {
                            best = (ex.exerciseName, v, log.completedAt)
                        }
                    }
                }
            }
            guard let b = best else { return nil }
            return (name: b.name, value: b.value, date: b.date)
        }
        // Stable order: value desc, then newest date first, then name asc.
        return rows.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            let l = lhs.date ?? .distantPast
            let r = rhs.date ?? .distantPast
            if l != r { return l > r }
            return lhs.name < rhs.name
        }
    }

    /// Local copy of WorkoutLogState's Epley formula so the dashboard can
    /// rank sets by estimated 1RM without exposing the helper publicly.
    private static func epley(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Full Personal Record leaderboard across every exercise that has any
    /// logged sets with weight, ranked by the heaviest set's weight. Used by
    /// the Top 100 detail sheet so it isn't limited to the tile's curated
    /// 5 exercises.
    private func personalRecordLeaderboard() -> [(name: String, value: Double, date: Date?)] {
        var best: [UUID: (name: String, value: Double, date: Date)] = [:]
        for log in logState.logs {
            for ex in log.exercises {
                for s in ex.sets where s.weight > 0 {
                    if let existing = best[ex.exerciseID] {
                        if s.weight > existing.value {
                            best[ex.exerciseID] = (ex.exerciseName, s.weight, log.completedAt)
                        }
                    } else {
                        best[ex.exerciseID] = (ex.exerciseName, s.weight, log.completedAt)
                    }
                }
            }
        }
        return best.values
            .map { (name: $0.name, value: $0.value, date: Optional($0.date)) }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                let l = lhs.date ?? .distantPast
                let r = rhs.date ?? .distantPast
                if l != r { return l > r }
                return lhs.name < rhs.name
            }
    }

    /// Full 1RM leaderboard across every exercise that has any sets producing
    /// a positive Epley estimate. Used by the Top 100 detail sheet.
    private func oneRMLeaderboard() -> [(name: String, value: Double, date: Date?)] {
        var best: [UUID: (name: String, value: Double, date: Date)] = [:]
        for log in logState.logs {
            for ex in log.exercises {
                for s in ex.sets {
                    let v = Self.epley(weight: s.weight, reps: s.reps)
                    guard v > 0 else { continue }
                    if let existing = best[ex.exerciseID] {
                        if v > existing.value {
                            best[ex.exerciseID] = (ex.exerciseName, v, log.completedAt)
                        }
                    } else {
                        best[ex.exerciseID] = (ex.exerciseName, v, log.completedAt)
                    }
                }
            }
        }
        return best.values
            .map { (name: $0.name, value: $0.value, date: Optional($0.date)) }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                let l = lhs.date ?? .distantPast
                let r = rhs.date ?? .distantPast
                if l != r { return l > r }
                return lhs.name < rhs.name
            }
    }

    /// Muscle group counts across an arbitrary date window. Mirrors the
    /// 7-day tile logic but lets the detail sheet swap in any cutoff.
    private func muscleDistributionSegments(since cutoff: Date) -> [PieSegment] {
        let recentLogs = logState.logs.filter { $0.completedAt >= cutoff }

        var counts: [String: Int] = [:]
        for log in recentLogs {
            let directMuscleIDs = log.primaryMuscleGroupIDs + log.secondaryMuscleGroupIDs
            if !directMuscleIDs.isEmpty {
                let names = directMuscleIDs.compactMap { id in
                    muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                }
                for name in names { counts[name, default: 0] += 1 }
            }
            for exercise in log.exercises {
                if let sourceExercise = exercisesState.exercises.first(where: { $0.id == exercise.exerciseID }) {
                    let muscleIDs = sourceExercise.primaryMuscleGroupIDs + sourceExercise.secondaryMuscleGroupIDs
                    let names = muscleIDs.compactMap { id in
                        muscleGroupsState.sortedGroups.first { $0.id == id }?.name
                    }
                    for name in names { counts[name, default: 0] += 1 }
                }
            }
        }

        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [] }

        let sorted = counts.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
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
        return segments
    }

    /// Volume bar series for the detail sheet. Bucket size is chosen by the
    /// caller — short ranges show per-week bars, longer ranges roll up to
    /// monthly to keep the chart legible.
    private func volumeBuckets(since cutoff: Date, workoutName: String?, exerciseID: UUID?, bucket: StatTimeRange.BucketPeriod) -> [(label: String, volume: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        switch bucket {
        case .week:  formatter.dateFormat = "MMM d"
        case .month: formatter.dateFormat = "MMM yy"
        case .day:   formatter.dateFormat = "MMM d"
        }

        var buckets: [(start: Date, end: Date, label: String)] = []
        switch bucket {
        case .day:
            var day = calendar.startOfDay(for: max(cutoff, calendar.date(byAdding: .day, value: -365, to: now) ?? cutoff))
            let last = calendar.startOfDay(for: now)
            while day <= last {
                let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                buckets.append((day, min(end, now), formatter.string(from: day)))
                day = end
            }
        case .week:
            guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: cutoff)?.start else { return [] }
            var weekStart = firstWeek
            while weekStart <= now {
                let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
                buckets.append((weekStart, min(weekEnd, now), formatter.string(from: weekStart)))
                weekStart = weekEnd
            }
        case .month:
            guard let firstMonth = calendar.dateInterval(of: .month, for: cutoff)?.start else { return [] }
            var monthStart = firstMonth
            while monthStart <= now {
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                buckets.append((monthStart, min(monthEnd, now), formatter.string(from: monthStart)))
                monthStart = monthEnd
            }
        }

        var results: [(label: String, volume: Double)] = []
        for b in buckets {
            var logsInBucket = logState.logsInRange(from: b.start, to: b.end)
            if let name = workoutName {
                logsInBucket = logsInBucket.filter { $0.workoutName == name }
            }
            var volume: Double = 0
            for log in logsInBucket {
                for ex in log.exercises {
                    if let exerciseID, ex.exerciseID != exerciseID { continue }
                    for s in ex.sets {
                        volume += Double(s.reps) * s.weight
                    }
                }
            }
            results.append((label: b.label, volume: volume))
        }
        return results
    }

    /// Top-5 exercises by how often they appear in logs (one count per
    /// LoggedExercise instance, matching the legacy `favoriteExercise`
    /// scalar). Sorted by count desc, ties broken by newest occurrence so the
    /// most recently used exercise wins ties instead of reshuffling.
    private func topFavoriteExerciseEntries() -> [(name: String, count: Int)] {
        let entries = favoriteExerciseAggregated()
        return Array(entries.prefix(5)).map { (name: $0.name, count: $0.count) }
    }

    /// Full Favorite Exercise leaderboard with deterministic ordering — used
    /// by both the dashboard tile (top 5) and the Top 100 detail sheet.
    private func favoriteExerciseAggregated() -> [(name: String, count: Int, lastDate: Date)] {
        var counts: [String: Int] = [:]
        var lastSeen: [String: Date] = [:]
        for log in logState.logs {
            for ex in log.exercises {
                counts[ex.exerciseName, default: 0] += 1
                let prev = lastSeen[ex.exerciseName] ?? .distantPast
                if log.completedAt > prev { lastSeen[ex.exerciseName] = log.completedAt }
            }
        }
        return counts
            .map { (name: $0.key, count: $0.value, lastDate: lastSeen[$0.key] ?? .distantPast) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if lhs.lastDate != rhs.lastDate { return lhs.lastDate > rhs.lastDate }
                return lhs.name < rhs.name
            }
    }

    /// Top sessions by duration (seconds). Each row references the exact
    /// LoggedExercise it came from, so a single exercise can appear multiple
    /// times if multiple long sessions stand out.
    private func topDurationEntries(for tile: DashboardTile, limit: Int = 5) -> [(name: String, value: Double, date: Date)] {
        let allowed: Set<UUID>? = tile.topDurationsExerciseIDs.flatMap { $0.isEmpty ? nil : Set($0) }
        let rows: [(name: String, value: Double, date: Date)] = logState.logs.flatMap { log in
            log.exercises.compactMap { ex -> (String, Double, Date)? in
                guard ex.activeSeconds > 0 else { return nil }
                if let allowed, !allowed.contains(ex.exerciseID) { return nil }
                return (ex.exerciseName, Double(ex.activeSeconds), log.completedAt)
            }.map { (name: $0.0, value: $0.1, date: $0.2) }
        }
        let sorted = rows.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.name < rhs.name
        }
        return Array(sorted.prefix(limit))
    }

    /// Top sessions by distance (meters). Filtered to the user-selected
    /// activity set when configured.
    private func topDistanceEntries(for tile: DashboardTile, limit: Int = 5) -> [(name: String, value: Double, date: Date)] {
        let allowed: Set<UUID>? = tile.topDistancesExerciseIDs.flatMap { $0.isEmpty ? nil : Set($0) }
        let rows: [(name: String, value: Double, date: Date)] = logState.logs.flatMap { log in
            log.exercises.compactMap { ex -> (String, Double, Date)? in
                guard let meters = ex.distanceMeters, meters > 0 else { return nil }
                if let allowed, !allowed.contains(ex.exerciseID) { return nil }
                return (ex.exerciseName, meters, log.completedAt)
            }.map { (name: $0.0, value: $0.1, date: $0.2) }
        }
        let sorted = rows.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.name < rhs.name
        }
        return Array(sorted.prefix(limit))
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

    @ViewBuilder
    private func statDetailDestination(for detail: StatDetailSheet) -> some View {
        switch detail {
        case .personalRecord(let tile):
            LeaderboardDetailView(
                title: tile.title.isEmpty ? StatCardType.personalRecord.rawValue : tile.title,
                icon: tile.icon,
                accentColor: tile.accentColor,
                kind: .weight(unit: weightUnit),
                entries: Array(personalRecordLeaderboard().prefix(100))
            )
        case .oneRepMax(let tile):
            LeaderboardDetailView(
                title: tile.title.isEmpty ? StatCardType.oneRepMax.rawValue : tile.title,
                icon: tile.icon,
                accentColor: tile.accentColor,
                kind: .weight(unit: weightUnit),
                entries: Array(oneRMLeaderboard().prefix(100))
            )
        case .topDurations(let tile):
            let entries = topDurationEntries(for: tile, limit: 100).map {
                (name: $0.name, value: $0.value, date: Optional($0.date))
            }
            LeaderboardDetailView(
                title: tile.title.isEmpty ? StatCardType.topDurations.rawValue : tile.title,
                icon: tile.icon,
                accentColor: tile.accentColor,
                kind: .duration,
                entries: entries
            )
        case .topDistances(let tile):
            let entries = topDistanceEntries(for: tile, limit: 100).map {
                (name: $0.name, value: $0.value, date: Optional($0.date))
            }
            LeaderboardDetailView(
                title: tile.title.isEmpty ? StatCardType.topDistances.rawValue : tile.title,
                icon: tile.icon,
                accentColor: tile.accentColor,
                kind: .distance(unit: distanceUnit),
                entries: entries
            )
        case .favoriteExercise(let tile):
            let entries = favoriteExerciseAggregated().prefix(100).map {
                (name: $0.name, value: Double($0.count), date: Optional($0.lastDate))
            }
            LeaderboardDetailView(
                title: tile.title.isEmpty ? StatCardType.favoriteExercise.rawValue : tile.title,
                icon: tile.icon,
                accentColor: tile.accentColor,
                kind: .count,
                entries: Array(entries)
            )
        case .volume(let tile):
            VolumeGraphDetailView(
                title: tile.title.isEmpty ? StatCardType.volumeThisWeek.rawValue : tile.title,
                icon: tile.icon,
                accentColor: tile.accentColor,
                tile: tile,
                bucketProvider: { range, tile in
                    volumeBuckets(
                        since: range.cutoffDate,
                        workoutName: tile.volumeWorkoutName,
                        exerciseID: tile.volumeExerciseID,
                        bucket: range.preferredBucket
                    )
                }
            )
        case .muscleGroups(let tile):
            MuscleGroupGraphDetailView(
                title: tile.title.isEmpty ? StatCardType.muscleGroupDistribution.rawValue : tile.title,
                icon: tile.icon,
                accentColor: tile.accentColor,
                segmentsProvider: { range in
                    muscleDistributionSegments(since: range.cutoffDate)
                }
            )
        }
    }

}

// MARK: - Stat Detail Sheet routing

enum StatDetailSheet: Identifiable {
    case personalRecord(DashboardTile)
    case oneRepMax(DashboardTile)
    case topDurations(DashboardTile)
    case topDistances(DashboardTile)
    case favoriteExercise(DashboardTile)
    case volume(DashboardTile)
    case muscleGroups(DashboardTile)

    var id: String {
        switch self {
        case .personalRecord(let t):    return "pr-\(t.id)"
        case .oneRepMax(let t):         return "rm-\(t.id)"
        case .topDurations(let t):      return "dur-\(t.id)"
        case .topDistances(let t):      return "dist-\(t.id)"
        case .favoriteExercise(let t):  return "fav-\(t.id)"
        case .volume(let t):            return "vol-\(t.id)"
        case .muscleGroups(let t):      return "mus-\(t.id)"
        }
    }
}

// MARK: - Stat time range (mirrors WaterTimeRange labels)

enum StatTimeRange: String, CaseIterable {
    case week        = "7D"
    case month       = "1M"
    case threeMonths = "3M"
    case sixMonths   = "6M"
    case year        = "1Y"
    case all         = "All"

    var label: String { rawValue }

    var cutoffDate: Date {
        let cal = Calendar.current
        switch self {
        case .week:        return cal.date(byAdding: .day,   value: -7,   to: Date()) ?? Date()
        case .month:       return cal.date(byAdding: .month, value: -1,   to: Date()) ?? Date()
        case .threeMonths: return cal.date(byAdding: .month, value: -3,   to: Date()) ?? Date()
        case .sixMonths:   return cal.date(byAdding: .month, value: -6,   to: Date()) ?? Date()
        case .year:        return cal.date(byAdding: .year,  value: -1,   to: Date()) ?? Date()
        case .all:         return Date.distantPast
        }
    }

    enum BucketPeriod { case day, week, month }

    /// Bucket granularity used by the volume graph so bars stay legible.
    var preferredBucket: BucketPeriod {
        switch self {
        case .week:        return .day
        case .month:       return .day
        case .threeMonths: return .week
        case .sixMonths:   return .week
        case .year:        return .month
        case .all:         return .month
        }
    }
}

// MARK: - Blank Tile Gesture Modifier

private struct BlankTileGestureModifier: ViewModifier {
    let tile: DashboardTile
    let isBlank: Bool
    let isSpinning: Bool
    @Binding var windUpDegrees: [UUID: Double]
    @Binding var lastDragAngle: [UUID: Double]
    @Binding var spinningTiles: [UUID: Double]
    let onRelease: (Double) -> Void
    let onTap: () -> Void

    // Max wind-up: 3 full rotations = 1080°
    private let maxWindUp: Double = 2160

    func body(content: Content) -> some View {
        if isBlank {
            content
                .background(GeometryReader { geo in
                    Color.clear.preference(key: TileCenterKey.self,
                        value: geo.frame(in: .global).center)
                })
                .onPreferenceChange(TileCenterKey.self) { _ in }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in
                            guard !isSpinning else { return }
                            // Compute tile center from drag start (first touch position relative to tile)
                            // Use the drag's startLocation as a proxy — we track angle relative to startLocation
                            let center = value.startLocation
                            let current = value.location
                            let angle = atan2(current.y - center.y, current.x - center.x) * 180 / .pi

                            if let last = lastDragAngle[tile.id] {
                                var delta = angle - last
                                // Normalize to [-180, 180]
                                if delta > 180 { delta -= 360 }
                                if delta < -180 { delta += 360 }

                                // CCW = negative delta in screen coords (y flipped)
                                // Negative delta = counterclockwise = winding up
                                if delta < 0 {
                                    let current = windUpDegrees[tile.id, default: 0]
                                    // Resistance increases as we approach max
                                    let resistance = 1.0 - (current / maxWindUp)
                                    let contribution = abs(delta) * max(resistance, 0.05)
                                    let newWound = min(current + contribution, maxWindUp)
                                    windUpDegrees[tile.id] = newWound
                                    // Rotate icon CCW to show wind-up
                                    withAnimation(.linear(duration: 0.016)) {
                                        spinningTiles[tile.id, default: 0] -= contribution
                                    }
                                    // Haptic tick every 90° of wind-up
                                    let prev = current / 90
                                    let next = newWound / 90
                                    if Int(next) > Int(prev) {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } else if delta > 0 {
                                    // Clockwise drag = slight unwind
                                    let current = windUpDegrees[tile.id, default: 0]
                                    let newWound = max(current - delta * 0.5, 0)
                                    windUpDegrees[tile.id] = newWound
                                    withAnimation(.linear(duration: 0.016)) {
                                        spinningTiles[tile.id, default: 0] += delta * 0.5
                                    }
                                }
                            }
                            lastDragAngle[tile.id] = angle
                        }
                        .onEnded { value in
                            lastDragAngle[tile.id] = nil
                            guard !isSpinning else { return }
                            let wound = windUpDegrees[tile.id, default: 0]
                            windUpDegrees[tile.id] = 0

                            // If barely moved, treat as a tap
                            let dist = hypot(value.translation.width, value.translation.height)
                            if dist < 8 && wound < 10 {
                                onTap()
                            } else {
                                onRelease(wound)
                            }
                        }
                )
        } else {
            content.onTapGesture { onTap() }
        }
    }
}

private struct TileCenterKey: PreferenceKey {
    static let defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { value = nextValue() }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

// MARK: - Checkmark Toggle Style

private struct CheckmarkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                configuration.label
                    .foregroundColor(.primary)
                Spacer()
                if configuration.isOn {
                    Image(systemName: "checkmark")
                        .foregroundColor(.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        case .personalRecord:
            return "medal"
        case .oneRepMax:
            return "trophy.fill"
        case .todaysPlan:
            return "calendar.badge.checkmark"
        case .waterIntake14Days:
            return "drop"
        case .topDurations:
            return "stopwatch"
        case .topDistances:
            return "ruler"
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
                    ForEach(moduleQuickOptions.indices, id: \.self) { i in
                        let module = moduleQuickOptions[i]
                        let isSelected = selectedModuleIDs.contains(module.id)
                        HStack {
                            Text(module.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if isSelected { selectedModuleIDs.remove(module.id) } else { selectedModuleIDs.insert(module.id) }
                        }
                    }
                }

                Section("Stat Cards") {
                    if statCardOptions.isEmpty {
                        Text("All stat cards are already added")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        ForEach(statCardOptions, id: \.self) { stat in
                            let isSelected = selectedStatCards.contains(stat)
                            Toggle(isOn: Binding(
                                get: { isSelected },
                                set: { on in
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if on { selectedStatCards.insert(stat) } else { selectedStatCards.remove(stat) }
                                }
                            )) {
                                Text(stat.rawValue)
                            }
                            .toggleStyle(CheckmarkToggleStyle())
                        }
                    }
                }

                Section("Mini Games") {
                    let matchSelected = selectedModuleIDs.contains(ModuleIDs.matchGame)
                    Toggle(isOn: Binding(
                        get: { matchSelected },
                        set: { on in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if on { selectedModuleIDs.insert(ModuleIDs.matchGame) } else { selectedModuleIDs.remove(ModuleIDs.matchGame) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Match 3")
                            Text("1000 levels of match-3. Collect powerups and level up.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(CheckmarkToggleStyle())
                }

                Section("Animator") {
                    let animatorSelected = selectedModuleIDs.contains(ModuleIDs.stickFigureAnimator)
                    Toggle(isOn: Binding(
                        get: { animatorSelected },
                        set: { on in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if on { selectedModuleIDs.insert(ModuleIDs.stickFigureAnimator) } else { selectedModuleIDs.remove(ModuleIDs.stickFigureAnimator) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stick Figure Animator")
                            Text("Build stick figure poses frame by frame and export animated GIFs for your exercises.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(CheckmarkToggleStyle())
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
                                        Image(systemName: "checkmark.circle.fill")
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
                            let size: TileSize = (statCard == .workoutFrequency || statCard == .muscleGroupDistribution || statCard == .oneRepMax || statCard == .personalRecord || statCard == .topDurations || statCard == .topDistances || statCard == .favoriteDay || statCard == .favoriteExercise || statCard == .volumeThisWeek || statCard == .waterIntake14Days || statCard == .todaysPlan) ? .large : .small
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
    /// For Top Durations tile: nil = all activities; non-nil = restricted set
    @State private var topDurationsExerciseIDs: [UUID]? = nil
    /// For Top Distances tile: nil = all activities; non-nil = restricted set
    @State private var topDistancesExerciseIDs: [UUID]? = nil

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
                || statCard == .volumeThisWeek || statCard == .favoriteDay
                || statCard == .favoriteExercise
                || statCard == .waterIntake14Days {
                return [.large]
            }
            if statCard == .oneRepMax || statCard == .personalRecord
                || statCard == .topDurations || statCard == .topDistances {
                return [.large]
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
                                            Image(systemName: "checkmark.circle.fill")
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
                                            Image(systemName: "checkmark.circle.fill")
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
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.primary)
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
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.primary)
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
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.primary)
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
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.primary)
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

                // Top Durations / Top Distances: activity filter — single `if`
                // (instead of two) keeps the Form's ViewBuilder statement count
                // under the threshold SwiftUI handles most reliably.
                if tile.statCardType == .topDurations || tile.statCardType == .topDistances {
                    activityFilterSection(
                        title: "Activities",
                        footerOn: "Showing top sessions across selected activities only.",
                        footerOff: "Showing top sessions across all activities. Select to restrict.",
                        eligiblePredicate: anyLoggedExercisePredicate,
                        selection: tile.statCardType == .topDurations
                            ? $topDurationsExerciseIDs
                            : $topDistancesExerciseIDs
                    )
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
                // Clamp to a permitted size for the tile type — fixes early
                // Top Durations/Distances tiles that were saved at .small
                // before the size rules included them.
                let allowed = availableSizes()
                selectedSize = allowed.contains(tile.size) ? tile.size : (allowed.first ?? tile.size)
                oneRMExerciseIDs = tile.oneRMExerciseIDs
                personalRecordExerciseIDs = tile.personalRecordExerciseIDs
                volumeWorkoutName = tile.volumeWorkoutName
                volumeExerciseID = tile.volumeExerciseID
                topDurationsExerciseIDs = tile.topDurationsExerciseIDs
                topDistancesExerciseIDs = tile.topDistancesExerciseIDs
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
                        updatedTile.topDurationsExerciseIDs = topDurationsExerciseIDs
                        updatedTile.topDistancesExerciseIDs = topDistancesExerciseIDs
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

    /// Predicate: exercise has appeared in at least one logged workout. Used
    /// by the Top Durations / Top Distances filters so both lists stay in sync
    /// regardless of which metric (duration vs. distance) is recorded.
    private var anyLoggedExercisePredicate: (Exercise) -> Bool {
        let loggedIDs = Set(logState.logs.flatMap { $0.exercises }.map { $0.exerciseID })
        return { ex in loggedIDs.contains(ex.id) }
    }

    /// Shared activity-filter section used by the Top Durations / Top Distances
    /// tiles. Eligibility is decided per-tile via `eligiblePredicate` (e.g. has
    /// a logged duration vs. has a logged distance).
    @ViewBuilder
    private func activityFilterSection(
        title: String,
        footerOn: String,
        footerOff: String,
        eligiblePredicate: (Exercise) -> Bool,
        selection: Binding<[UUID]?>
    ) -> some View {
        Section {
            let eligible = exercisesState.exercises
                .filter(eligiblePredicate)
                .sorted { $0.name < $1.name }
            if eligible.isEmpty {
                Text("No eligible activities yet — complete a session first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let selected = selection.wrappedValue ?? []
                ForEach(eligible) { exercise in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        var ids = selection.wrappedValue ?? []
                        if ids.contains(exercise.id) {
                            ids.removeAll { $0 == exercise.id }
                        } else {
                            ids.append(exercise.id)
                        }
                        selection.wrappedValue = ids.isEmpty ? nil : ids
                    }) {
                        HStack {
                            Text(exercise.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selected.contains(exercise.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text(title)
        } footer: {
            Text(selection.wrappedValue == nil ? footerOff : footerOn)
                .font(.caption)
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
    var oneRMEntries: [(name: String, value: Double, date: Date?)] = []
    var personalRecordEntries: [(name: String, value: Double, date: Date?)] = []
    var volumeWeeks: [(label: String, volume: Double)] = []
    var dayOfWeekCounts: [(label: String, count: Int)] = []
    /// Top-5 exercises by appearance count, used by the Favorite Exercise
    /// leaderboard tile.
    var favoriteExerciseEntries: [(name: String, count: Int)] = []
    var waterDailyTotals: [(date: Date, oz: Double)] = []
    var waterGoalOz: Double = 64
    var waterUnit: WaterUnit = .oz
    var waterStreak: Int = 0
    /// Longest / current workout streaks, surfaced under the Workout
    /// Frequency dot grid in place of the retired streak stat cards.
    var longestStreak: Int = 0
    var currentStreak: Int = 0
    var topDurationEntries: [(name: String, value: Double, date: Date)] = []
    var topDistanceEntries: [(name: String, value: Double, date: Date)] = []
    var distanceUnit: String = "mi"

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var iPad: Bool { sizeClass == .regular }

    var body: some View {
        let bg = tileTint ?? defaultBackground ?? Color(UIColor.secondarySystemBackground)
        let tileBorder: Color = tileTint != nil ? .clear : (borderColor ?? .clear)
        ZStack(alignment: .topLeading) {
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
                    // Tap-hint glyph for stat cards that route the user into
                    // a module on tap (currently water — others render purely
                    // informational data and shouldn't suggest interactivity).
                    if statType == .waterIntake14Days {
                        Image(systemName: "chevron.right")
                            .font(.system(size: iPad ? 13 : 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                Spacer().frame(height: 4)

                // Data / Content
                if statType == .workoutFrequency {
                    VStack(spacing: 6) {
                        WeekFrequencyView(days: frequencyDays)
                            .frame(maxHeight: .infinity)
                        Text(frequencyRangeLabel)
                            .font(.system(size: iPad ? 16 : 10))
                            .foregroundColor(.gray)

                        // Streak row — Longest on the left half, Current on
                        // the right half. Keeps the trio (dots + range +
                        // streaks) compact instead of stacking two label/value
                        // rows underneath.
                        HStack(spacing: 8) {
                            streakHalf(label: "Longest Streak", value: longestStreak)
                            streakHalf(label: "Current Streak", value: currentStreak, systemIcon: "flame.fill")
                        }
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)
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
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        // Rank badge
                                        Text("#\(index + 1)")
                                            .font(.system(size: iPad ? 16 : 12, weight: .bold, design: .rounded))
                                            .foregroundColor(index == 0 ? .yellow : .gray)
                                            .frame(width: iPad ? 36 : 24, alignment: .leading)
                                        // Exercise name + date stamp (mirrors the Top Durations row layout)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.name)
                                                .font(.system(size: iPad ? 16 : 12, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                            if let date = entry.date {
                                                Text(date, format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                                                    .font(.system(size: iPad ? 12 : 9))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        // 1RM value
                                        Text(String(format: "%.0f", entry.value))
                                            .font(.system(size: iPad ? 16 : 12, weight: .bold))
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
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("#\(index + 1)")
                                            .font(.system(size: iPad ? 16 : 12, weight: .bold, design: .rounded))
                                            .foregroundColor(index == 0 ? Color(red: 1, green: 0.8, blue: 0) : .gray)
                                            .frame(width: iPad ? 36 : 24, alignment: .leading)
                                        // Exercise name + date stamp (mirrors the Top Durations row layout)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.name)
                                                .font(.system(size: iPad ? 16 : 12, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                            if let date = entry.date {
                                                Text(date, format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                                                    .font(.system(size: iPad ? 12 : 9))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(String(format: "%.0f", entry.value))
                                            .font(.system(size: iPad ? 16 : 12, weight: .bold))
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if statType == .muscleGroupDistribution {
                    GeometryReader { geometry in
                        let maxHeight = geometry.size.height
                        let maxWidth  = geometry.size.width
                        let pieSize   = iPad ? min(maxHeight * 0.82, maxWidth * 0.38) : min(maxHeight * 0.9, maxWidth * 0.55)

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
                } else if statType == .waterIntake14Days {
                    if waterDailyTotals.isEmpty || waterDailyTotals.allSatisfy({ $0.oz == 0 }) {
                        VStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "drop")
                                .font(.system(size: iPad ? 35 : 22, weight: .light))
                                .foregroundColor(.gray)
                            Text("No water logged yet")
                                .font(.system(size: iPad ? 16 : 10))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 4) {
                            WaterBarChartView(
                                totals: waterDailyTotals,
                                goalOz: waterGoalOz,
                                maxOz: max(waterDailyTotals.map { $0.oz }.max() ?? waterGoalOz, waterGoalOz),
                                unit: waterUnit
                            )
                            .frame(maxWidth: .infinity)
                            if waterStreak > 0 {
                                HStack(spacing: 4) {
                                    Spacer()
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: iPad ? 13 : 9, weight: .bold))
                                        .foregroundColor(.orange)
                                    Text("\(waterStreak) day streak")
                                        .font(.system(size: iPad ? 13 : 9))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
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
                } else if statType == .favoriteExercise {
                    if favoriteExerciseEntries.isEmpty {
                        VStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "star")
                                .font(.system(size: iPad ? 35 : 22, weight: .light))
                                .foregroundColor(.gray)
                            Text("No exercises logged yet")
                                .font(.system(size: iPad ? 16 : 10))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Anchor the chart to the top so the (up to) 5 rows
                        // sit just under the header instead of expanding to
                        // fill the 7-row tile height with row gaps.
                        VStack(spacing: 0) {
                            FavoriteExerciseBarChartView(entries: favoriteExerciseEntries)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if statType == .topDurations || statType == .topDistances {
                    let entries = statType == .topDurations ? topDurationEntries : topDistanceEntries
                    if entries.isEmpty {
                        VStack(spacing: 4) {
                            Spacer()
                            Image(systemName: statType == .topDurations ? "stopwatch" : "ruler")
                                .font(.system(size: iPad ? 35 : 22, weight: .light))
                                .foregroundColor(.gray)
                            Text(statType == .topDurations
                                 ? "Log durations to see\nyour top sessions"
                                 : "Log distances to see\nyour top sessions")
                                .font(.system(size: iPad ? 16 : 10))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        let best = entries.map { $0.value }.max() ?? 1
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(entries.prefix(10).enumerated()), id: \.offset) { index, entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("#\(index + 1)")
                                            .font(.system(size: iPad ? 16 : 12, weight: .bold, design: .rounded))
                                            .foregroundColor(index == 0 ? .yellow : .gray)
                                            .frame(width: iPad ? 36 : 24, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.name)
                                                .font(.system(size: iPad ? 16 : 12, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                            Text(entry.date, format: .dateTime.month(.abbreviated).day().year(.twoDigits))
                                                .font(.system(size: iPad ? 12 : 9))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(statType == .topDurations
                                             ? formatTopDuration(seconds: entry.value)
                                             : DistanceFormatter.format(meters: entry.value, unit: distanceUnit))
                                            .font(.system(size: iPad ? 16 : 12, weight: .bold))
                                            .foregroundColor(.primary)
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.primary.opacity(0.08))
                                                .frame(height: 3)
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(index == 0 ? Color.yellow : Color.primary.opacity(0.35))
                                                .frame(width: geo.size.width * CGFloat(best > 0 ? entry.value / best : 0), height: 3)
                                        }
                                    }
                                    .frame(height: 3)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    // The big-number variant only renders for the volume +
                    // PR fallback paths now; everything else has its own
                    // dedicated chart/list above. Keep design-default (not
                    // .rounded) so the volume value matches earlier UI.
                    let isNumeric = false
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Text(value)
                            .font(.system(size: isNumeric ? (iPad ? 44 : 28) : (iPad ? 25 : 16), weight: .bold, design: isNumeric ? .rounded : .default))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Trend arrow below the main value
                        if let t = trend {
                            Text(t.symbol)
                                .font(.system(size: iPad ? 20 : 13, weight: .bold))
                                .foregroundColor(t.color)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        // Secondary label for Personal Record card
                        if statType == .personalRecord, let exercise = personalRecordLabel {
                            Text(exercise)
                                .font(.system(size: iPad ? 16 : 10))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// One half of the streak row under the Workout Frequency dot grid —
    /// label and value side-by-side. Two of these share the row so Longest
    /// Streak sits on the leading half and Current Streak on the trailing
    /// half, each as a tight label/value pair.
    @ViewBuilder
    private func streakHalf(label: String, value: Int, systemIcon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon = systemIcon {
                            Image(systemName: icon)
                                .font(.system(size: iPad ? 13 : 9, weight: .bold))
                                .foregroundColor(.orange)
                        }
            Text(label)
                .font(.system(size: iPad ? 16 : 10))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(value)")
                .font(.system(size: iPad ? 16 : 10, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    /// "1:23:45" / "12:34" / "45s" — compact duration formatting for the
    /// leaderboard value column.
    private func formatTopDuration(seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        if m > 0 { return String(format: "%d:%02d", m, s) }
        return "\(s)s"
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
                    Spacer(minLength: 0)
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
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(iPad ? 10 : 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // Let the canvas render `overflow` points above its layout bounds
        // so the topmost dot + 4pt glow stroke can extend above the bar
        // ceiling without being clipped — bars stay at full barAreaH, the
        // trend dot still sits on top of each bar.
        let overflow: CGFloat = 8
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
        .padding(.top, -overflow)
        .allowsHitTesting(false)
    }
}

private struct VolumeBarChartView: View {
    let weeks: [(label: String, volume: Double)]

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedIndex: Int? = nil

    private static let tooltipFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

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
                let availableWidth = max(geo.size.width, 1)
                let barWidth = (availableWidth - barSpacing * CGFloat(weeks.count - 1)) / CGFloat(max(weeks.count, 1))
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                            let fraction = CGFloat(fractions[idx])
                            let barHeight = week.volume > 0 ? max(iPad ? 28 : 18, barAreaH * fraction) : 0
                            let isCurrentWeek = idx == currentWeekIdx
                            let isSelected = selectedIndex == idx
                            let hasSelection = selectedIndex != nil
                            let barOpacity: Double = hasSelection ? (isSelected ? 1.0 : 0.3) : 1.0
                            VStack(spacing: 3) {
                                ZStack {
                                    if week.volume > 0 {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill((isCurrentWeek ? Color.primary : Color.primary.opacity(0.35)).opacity(barOpacity))
                                            .frame(height: barHeight)
                                        let volLabel = week.volume >= 1000
                                            ? String(format: "%.1fk", week.volume / 1000)
                                            : String(format: "%.0f", week.volume)
                                        Text(volLabel)
                                            .font(.system(size: iPad ? 17 : 11, weight: .bold))
                                            .foregroundColor(isCurrentWeek ? Color(UIColor.systemBackground) : Color.primary.opacity(0.7))
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                            .opacity(barOpacity)
                                    }
                                }
                                .frame(height: barHeight)
                                Text(week.label)
                                    .font(.system(size: iPad ? 15 : 10, weight: isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected ? .primary : .gray)
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

                    // Gesture layer — covers bar area only
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity)
                        .frame(height: barAreaH)
                        .offset(y: -(labelH / 2))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let idx = Int(value.location.x / (barWidth + barSpacing))
                                    let clamped = max(0, min(weeks.count - 1, idx))
                                    if selectedIndex != clamped {
                                        selectedIndex = clamped
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) { selectedIndex = nil }
                                }
                        )

                    // Tooltip popup
                    if let idx = selectedIndex, idx < weeks.count {
                        let week = weeks[idx]
                        let fraction = CGFloat(fractions[idx])
                        let barH = week.volume > 0 ? max(iPad ? 28 : 18, barAreaH * fraction) : CGFloat(0)
                        let barX = CGFloat(idx) * (barWidth + barSpacing)
                        let tipW: CGFloat = iPad ? 120 : 90
                        let tipH: CGFloat = iPad ? 44 : 34
                        let tipPad: CGFloat = 6
                        let rawX = barX + barWidth / 2
                        let clampedX = min(max(rawX, tipW / 2), availableWidth - tipW / 2)
                        let tipY = max(tipH / 2 + 2, barAreaH - barH - tipPad - tipH / 2)
                        let volLabel = week.volume >= 1000
                            ? String(format: "%.1fk", week.volume / 1000)
                            : String(format: "%.0f", week.volume)
                        let valueText = week.volume > 0 ? volLabel : "No data"

                        VStack(spacing: 2) {
                            Text(valueText)
                                .font(.system(size: iPad ? 13 : 11, weight: .bold))
                                .foregroundColor(.primary)
                            Text(week.label)
                                .font(.system(size: iPad ? 11 : 9))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(minWidth: tipW)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        )
                        .position(x: clampedX, y: tipY)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(10)
                    }
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
        // Calculate the width needed for the largest count value. Bumped to
        // match the Top Durations text size (12pt phone / 16pt iPad).
        let maxCountWidth: CGFloat = {
            let maxDigits = String(maxCount).count
            return iPad ? CGFloat(max(32, maxDigits * 11)) : CGFloat(max(26, maxDigits * 8))
        }()

        VStack(alignment: .leading, spacing: iPad ? 10 : 5) {
            ForEach(Array(sorted.enumerated()), id: \.offset) { idx, day in
                let fraction = maxCount > 0 ? CGFloat(day.count) / CGFloat(maxCount) : 0
                HStack(spacing: iPad ? 10 : 6) {
                    // Day label + value sized to match the Top Durations
                    // leaderboard rows (16/12) so the tiles read consistently.
                    Text(String(day.label.prefix(3)))
                        .font(.system(size: iPad ? 16 : 12, weight: idx == 0 ? .bold : .semibold))
                        .foregroundColor(idx == 0 ? .primary : .gray)
                        .frame(width: iPad ? 46 : 30, alignment: .leading)
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
                        .font(.system(size: iPad ? 16 : 12, weight: .bold))
                        .foregroundColor(idx == 0 ? .primary : .gray)
                        .frame(width: maxCountWidth, alignment: .trailing)
                }
                .frame(height: iPad ? 24 : 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Favorite Exercise Bar Chart (horizontal)

/// Top-5 exercises ranked by appearance count. Uses `Grid` so the name
/// column auto-sizes to the widest entry — every bar starts at the same x,
/// stretches across the rest of the row, and the count column right-aligns.
/// Reads identically to `DayOfWeekBarChartView` at the same font scale
/// (16pt iPad / 12pt phone), matching the Top Durations leaderboard rows.
private struct FavoriteExerciseBarChartView: View {
    let entries: [(name: String, count: Int)]

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let iPad = sizeClass == .regular
        let sorted = entries.sorted { $0.count > $1.count }
        let maxCount = sorted.map { $0.count }.max() ?? 1
        let maxCountWidth: CGFloat = {
            let maxDigits = String(maxCount).count
            return iPad ? CGFloat(max(32, maxDigits * 11)) : CGFloat(max(26, maxDigits * 8))
        }()

        Grid(alignment: .leading,
             horizontalSpacing: iPad ? 10 : 6,
             verticalSpacing: iPad ? 10 : 5) {
            ForEach(Array(sorted.enumerated()), id: \.offset) { idx, entry in
                let fraction = maxCount > 0 ? CGFloat(entry.count) / CGFloat(maxCount) : 0
                GridRow {
                    Text(entry.name)
                        .font(.system(size: iPad ? 16 : 12, weight: idx == 0 ? .bold : .semibold))
                        .foregroundColor(idx == 0 ? .primary : .gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .gridColumnAlignment(.leading)
                    // Bar column fills the rest of the row — every bar
                    // starts at the right edge of the (auto-sized) name
                    // column, so they line up across rows.
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
                    .frame(maxWidth: .infinity)
                    .frame(height: iPad ? 18 : 10)
                    Text("\(entry.count)")
                        .font(.system(size: iPad ? 16 : 12, weight: .bold))
                        .foregroundColor(idx == 0 ? .primary : .gray)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: maxCountWidth, alignment: .trailing)
                        .gridColumnAlignment(.trailing)
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

    @State private var selectedIndex: Int? = nil

    private var isDummyChart: Bool {
        segments.count == 1 && segments[0].value == 1.0 && segments[0].color == .gray
    }

    var body: some View {
        GeometryReader { geometry in
            PieChartCanvas(
                segments: segments,
                isDummyChart: isDummyChart,
                size: geometry.size,
                selectedIndex: $selectedIndex
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
    @Binding var selectedIndex: Int?

    private var outerRadius: CGFloat { min(size.width, size.height) / 2 }
    private var innerRadius: CGFloat { outerRadius * 0.34 }
    private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    /// Returns the segment index hit-tested at a point, or nil if inside the hole or outside
    private func segmentIndex(at point: CGPoint) -> Int? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist >= innerRadius && dist <= outerRadius else { return nil }
        // atan2 gives angle from positive x-axis; our slices start at -90°
        var angle = Foundation.atan2(dy, dx) * 180 / .pi  // -180...180
        angle += 90  // shift so 0° = top
        if angle < 0 { angle += 360 }  // 0...360
        let total = segments.map { $0.value }.reduce(0, +)
        var accumulated = 0.0
        for (i, seg) in segments.enumerated() {
            let sweep = (seg.value / total) * 360
            if angle < accumulated + sweep { return i }
            accumulated += sweep
        }
        return nil
    }

    var body: some View {
        ZStack {
            ForEach(segments.indices, id: \.self) { index in
                let isSelected = selectedIndex == index
                let hasSelection = selectedIndex != nil
                let sliceOpacity: Double = hasSelection ? (isSelected ? 1.0 : 0.3) : 1.0

                DonutSegmentShape(
                    startAngle: angleStart(at: index),
                    endAngle: angleEnd(at: index),
                    outerRadius: isSelected ? outerRadius * 1.06 : outerRadius,
                    innerRadius: innerRadius,
                    center: center
                )
                .fill(segments[index].color.opacity(sliceOpacity))

                if segments.count > 1 {
                    DonutSeparatorShape(
                        angle: angleStart(at: index),
                        innerRadius: innerRadius,
                        outerRadius: isSelected ? outerRadius * 1.06 : outerRadius,
                        center: center
                    )
                    .stroke(Color.white, lineWidth: 1.5)
                }

                // Percentage label in the middle of the ring arc — only for segments ≥ 8%
                if !isDummyChart {
                    percentageLabel(at: index, sliceOpacity: sliceOpacity)
                }
            }

            // Center hole
            Circle()
                .fill(Color(uiColor: .systemGray6))
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .position(center)

            // Tooltip in center hole when a slice is selected
            if let idx = selectedIndex, idx < segments.count, !isDummyChart {
                let seg = segments[idx]
                let total = segments.map { $0.value }.reduce(0, +)
                let pct = total > 0 ? Int((seg.value / total * 100).rounded()) : 0
                VStack(spacing: 1) {
                    Text("\(pct)%")
                        .font(.system(size: max(9, innerRadius * 0.38), weight: .bold))
                        .foregroundColor(.primary)
                    Text(seg.label)
                        .font(.system(size: max(7, innerRadius * 0.28), weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: innerRadius * 1.7)
                }
                .position(center)
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(10)
            }

            // Gesture layer — long press to select, drag to switch, release to deselect
            Color.clear
                .contentShape(Rectangle())
                .frame(width: size.width, height: size.height)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newIdx = segmentIndex(at: value.location)
                            if newIdx != selectedIndex {
                                selectedIndex = newIdx
                                if newIdx != nil {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.25)) { selectedIndex = nil }
                        }
                )
        }
    }

    @ViewBuilder
    private func percentageLabel(at index: Int, sliceOpacity: Double = 1.0) -> some View {
        let total = segments.map { $0.value }.reduce(0, +)
        let fraction = total > 0 ? segments[index].value / total : 0
        // Only show label when segment is large enough to fit text and not dimmed
        if fraction >= 0.08 && sliceOpacity > 0.5 {
            let isSelected = selectedIndex == index
            let effectiveOuter = isSelected ? outerRadius * 1.06 : outerRadius
            let start = angleStart(at: index)
            let end = angleEnd(at: index)
            let midAngle = Angle.degrees((start.degrees + end.degrees) / 2)
            // Position label in the middle of the ring band
            let labelRadius = (innerRadius + effectiveOuter) / 2
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
                        // Tap-hint glyph so the user knows the tile launches
                        // the plan, not just a static summary.
                        Image(systemName: "chevron.right")
                            .font(.system(size: iPad ? 13 : 9, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer(minLength: 0)
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
                        
                        // Display note if present
                        if !pd.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "note.text")
                                    .font(.system(size: iPad ? 16 : 10))
                                    .foregroundColor(.secondary)
                                Text(pd.note)
                                    .font(.system(size: iPad ? 16 : 10))
                                    .foregroundColor(.secondary)
                                    //.lineLimit(2)
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
// MARK: - Leaderboard Detail Sheet

/// Generic Top-N leaderboard for a stat tile. Renders the same row design
/// the dashboard tile uses (rank badge + name/date column + value column +
/// progress bar) but scrolls and supports up to 100 entries.
fileprivate struct LeaderboardDetailView: View {
    enum ValueKind {
        case weight(unit: String)
        case duration
        case distance(unit: String)
        case count
    }

    let title: String
    let icon: String
    let accentColor: Color
    let kind: ValueKind
    let entries: [(name: String, value: Double, date: Date?)]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var iPad: Bool { sizeClass == .regular }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(.gray)
                        Text("No data yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let best = entries.map { $0.value }.max() ?? 1
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                                row(index: index, entry: entry, best: best)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(index: Int, entry: (name: String, value: Double, date: Date?), best: Double) -> some View {
        let highlight = index == 0 ? accentRowColor : Color.gray
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text("#\(index + 1)")
                    .font(.system(size: iPad ? 18 : 14, weight: .bold, design: .rounded))
                    .foregroundColor(index == 0 ? accentRowColor : .gray)
                    .frame(width: iPad ? 48 : 36, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: iPad ? 17 : 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let date = entry.date, date > .distantPast {
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.system(size: iPad ? 13 : 11))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(valueLabel(entry.value))
                    .font(.system(size: iPad ? 17 : 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(highlight)
                        .frame(width: geo.size.width * CGFloat(best > 0 ? entry.value / best : 0), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 4)
    }

    private var accentRowColor: Color {
        // Use the tile's accent color if it was customized, otherwise default
        // to the same gold the dashboard tiles use for the #1 row.
        accentColor == Color(red: 0.8, green: 0.8, blue: 0.8) ? Color(red: 1, green: 0.8, blue: 0) : accentColor
    }

    private func valueLabel(_ value: Double) -> String {
        switch kind {
        case .weight(let unit):
            return String(format: "%.0f \(unit)", value)
        case .duration:
            return formatDuration(seconds: value)
        case .distance(let unit):
            return DistanceFormatter.format(meters: value, unit: unit)
        case .count:
            return "\(Int(value))"
        }
    }

    private func formatDuration(seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        if m > 0 { return String(format: "%d:%02d", m, s) }
        return "\(s)s"
    }
}

// MARK: - Volume Graph Detail Sheet

/// Full-screen Volume This Week detail. Mirrors the Water Graphs sheet's
/// segmented time-range picker (7D / 1M / 3M / 6M / 1Y / All) and re-uses
/// the dashboard's VolumeBarChartView so the bars match the tile.
fileprivate struct VolumeGraphDetailView: View {
    let title: String
    let icon: String
    let accentColor: Color
    let tile: DashboardTile
    let bucketProvider: (StatTimeRange, DashboardTile) -> [(label: String, volume: Double)]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @State private var selectedRange: StatTimeRange = .week

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Range", selection: $selectedRange) {
                    ForEach(StatTimeRange.allCases, id: \.self) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                ScrollView {
                    let buckets = bucketProvider(selectedRange, tile)
                    if buckets.isEmpty || buckets.allSatisfy({ $0.volume == 0 }) {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 44, weight: .light))
                                .foregroundColor(.gray)
                            Text("No volume logged in this range")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: icon)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(selectedRange.label)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                let total = buckets.reduce(0.0) { $0 + $1.volume }
                                let totalLabel = total >= 1000
                                    ? String(format: "%.1fk \(weightUnit)", total / 1000)
                                    : String(format: "%.0f \(weightUnit)", total)
                                Text(totalLabel)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            DetailVolumeBarChart(buckets: buckets)
                                .frame(height: 220)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .padding(16)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Standalone bar chart for the Volume detail sheet. Re-implemented (instead
/// of reusing the private `VolumeBarChartView`) so it can size and scroll
/// when a range has many buckets without distorting the dashboard tile.
private struct DetailVolumeBarChart: View {
    let buckets: [(label: String, volume: Double)]

    @State private var selectedIndex: Int? = nil

    var body: some View {
        let maxVol = buckets.map { $0.volume }.max() ?? 1
        let barSpacing: CGFloat = 6
        // Cap to a minimum bar width so very long ranges scroll horizontally.
        let minBarWidth: CGFloat = 22
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let proposedBarWidth = (availableWidth - barSpacing * CGFloat(max(buckets.count - 1, 0))) / CGFloat(max(buckets.count, 1))
            let barWidth = max(minBarWidth, proposedBarWidth)
            let contentWidth = barWidth * CGFloat(buckets.count) + barSpacing * CGFloat(max(buckets.count - 1, 0))

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(Array(buckets.enumerated()), id: \.offset) { idx, bucket in
                            let fraction = maxVol > 0 ? CGFloat(bucket.volume / maxVol) : 0
                            let isSelected = selectedIndex == idx
                            let hasSelection = selectedIndex != nil
                            let barOpacity: Double = hasSelection ? (isSelected ? 1.0 : 0.3) : 1.0
                            VStack(spacing: 4) {
                                ZStack(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: barWidth, height: 180)
                                    if bucket.volume > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.primary.opacity(barOpacity))
                                            .frame(width: barWidth, height: max(8, 180 * fraction))
                                    }
                                }
                                Text(bucket.label)
                                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected ? .primary : .gray)
                                    .lineLimit(1)
                                    .frame(width: barWidth)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedIndex = selectedIndex == idx ? nil : idx
                            }
                        }
                    }
                    if let idx = selectedIndex, idx < buckets.count {
                        let b = buckets[idx]
                        let label = b.volume >= 1000
                            ? String(format: "%.1fk", b.volume / 1000)
                            : String(format: "%.0f", b.volume)
                        Text("\(b.label): \(label)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.leading, 4)
                    }
                }
                .frame(width: max(contentWidth, availableWidth), alignment: .leading)
            }
        }
    }
}

// MARK: - Muscle Group Distribution Detail Sheet

/// Full-screen Muscle Group Distribution with the standard 7D/1M/3M/6M/1Y/All
/// picker. Uses the same donut chart canvas the tile renders, just larger.
fileprivate struct MuscleGroupGraphDetailView: View {
    let title: String
    let icon: String
    let accentColor: Color
    let segmentsProvider: (StatTimeRange) -> [PieSegment]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: StatTimeRange = .week

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Range", selection: $selectedRange) {
                    ForEach(StatTimeRange.allCases, id: \.self) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                let segments = segmentsProvider(selectedRange)
                ScrollView {
                    if segments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 44, weight: .light))
                                .foregroundColor(.gray)
                            Text("No muscle groups logged in this range")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        VStack(spacing: 24) {
                            DetailPieChart(segments: segments)
                                .frame(width: 260, height: 260)
                                .padding(.top, 24)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                                    HStack(spacing: 10) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(seg.color)
                                            .frame(width: 14, height: 14)
                                        Text(seg.label)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(Int((seg.value * 100).rounded()))%")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Lightweight donut chart used only by the muscle-group detail sheet.
/// Mirrors the dashboard tile's donut without bringing in its private types.
private struct DetailPieChart: View {
    let segments: [PieSegment]
    @State private var selectedIndex: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let outerR = size / 2
            let innerR = outerR * 0.36
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                ForEach(segments.indices, id: \.self) { i in
                    let isSelected = selectedIndex == i
                    let hasSelection = selectedIndex != nil
                    let opacity = hasSelection ? (isSelected ? 1.0 : 0.3) : 1.0
                    PieSlicePath(
                        startAngle: angleStart(i),
                        endAngle: angleEnd(i),
                        outerRadius: isSelected ? outerR * 1.05 : outerR,
                        innerRadius: innerR,
                        center: center
                    )
                    .fill(segments[i].color.opacity(opacity))
                }
                Circle()
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: innerR * 2, height: innerR * 2)
                    .position(center)

                if let i = selectedIndex, i < segments.count {
                    let seg = segments[i]
                    VStack(spacing: 2) {
                        Text("\(Int((seg.value * 100).rounded()))%")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        Text(seg.label)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(width: innerR * 1.7)
                            .lineLimit(2)
                    }
                    .position(center)
                    .allowsHitTesting(false)
                }

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newIdx = hitTest(point: value.location, center: center, innerR: innerR, outerR: outerR)
                                if newIdx != selectedIndex {
                                    selectedIndex = newIdx
                                    if newIdx != nil {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.25)) { selectedIndex = nil }
                            }
                    )
            }
        }
    }

    private func angleStart(_ index: Int) -> Angle {
        let total = segments.map { $0.value }.reduce(0, +)
        let prior = segments.prefix(index).map { $0.value }.reduce(0, +)
        return .degrees((prior / total) * 360 - 90)
    }

    private func angleEnd(_ index: Int) -> Angle {
        let total = segments.map { $0.value }.reduce(0, +)
        let current = segments.prefix(index + 1).map { $0.value }.reduce(0, +)
        return .degrees((current / total) * 360 - 90)
    }

    private func hitTest(point: CGPoint, center: CGPoint, innerR: CGFloat, outerR: CGFloat) -> Int? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist >= innerR && dist <= outerR else { return nil }
        var angle = Foundation.atan2(dy, dx) * 180 / .pi
        angle += 90
        if angle < 0 { angle += 360 }
        let total = segments.map { $0.value }.reduce(0, +)
        var acc = 0.0
        for (i, seg) in segments.enumerated() {
            let sweep = (seg.value / total) * 360
            if angle < acc + sweep { return i }
            acc += sweep
        }
        return nil
    }
}

private struct PieSlicePath: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }
}

