////
////  DashboardModule.swift
////  Extend
////
////  Created by CAVAN MANNENBACH on 2/12/26.
////

import SwiftUI
import Observation
import UIKit

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

    @Environment(DashboardState.self) var dashboardState
    @Environment(ModuleRegistry.self) var registry
    @Environment(ModuleState.self) var state
    @Environment(WorkoutLogState.self) var logState
    @Environment(ExercisesState.self) var exercisesState
    @Environment(MuscleGroupsState.self) var muscleGroupsState
    @Environment(DashboardHeaderState.self) var headerState
    @Environment(WorkoutsState.self) var workoutsState
    @Environment(TimerState.self) var timerState
    @Environment(VoiceTrainerState.self) var voiceTrainerState
    
    @State private var spinningTiles: [UUID: Double] = [:]
    @State private var flyingTiles: Set<UUID> = []
    @State private var tileOffsets: [UUID: (x: CGFloat, y: CGFloat)] = [:]
    @State private var tileRotations: [UUID: Double] = [:]
    @State private var showBlankAlert = false
    @State private var blankAlertMessage = ""
    
    // Track game levels for reactive UI updates
    @State private var game1Level: Int = 1
    @State private var matchGameLevel: Int = 1
    @State private var refreshTrigger: UUID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
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
        .alert("Blank Tile", isPresented: $showBlankAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(blankAlertMessage)
        }
        .onAppear {
            // Initialize game levels from UserDefaults
            if let statsDict = UserDefaults.standard.dictionary(forKey: "game1_stats"),
               let savedLevel = statsDict["currentLevel"] as? Int {
                game1Level = savedLevel > 0 ? savedLevel : 1
            } else {
                game1Level = 1
            }
            
            matchGameLevel = UserDefaults.standard.integer(forKey: "matchGameCurrentLevel")
            if matchGameLevel <= 0 { matchGameLevel = 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh game levels when app becomes active (returning from game)
            if let statsDict = UserDefaults.standard.dictionary(forKey: "game1_stats"),
               let savedLevel = statsDict["currentLevel"] as? Int {
                game1Level = savedLevel > 0 ? savedLevel : 1
            } else {
                game1Level = 1
            }
            
            matchGameLevel = UserDefaults.standard.integer(forKey: "matchGameCurrentLevel")
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
                VStack(spacing: 10) {
                    let rows = tileRows()
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        tilesRowView(row: row, columnWidth: columnWidth, spacing: spacing)
                    }
                }
                .padding(10)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private func tilesRowView(row: [DashboardTile], columnWidth: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
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
        let tileHeight = isDoubleHeight ? columnWidth * 2 + spacing : columnWidth
        
        return Group {
            if tile.tileType == .statCard, let statCard = tile.statCardType {
                StatCardTileView(
                    title: statCard.rawValue,
                    icon: tile.icon,
                    value: statValue(for: statCard),
                    statType: statCard,
                    frequencyDays: workoutFrequencyDays(),
                    frequencyRangeLabel: workoutFrequencyRangeLabel(),
                    muscleSegments: muscleDistributionSegments(),
                    accentPlacement: tile.accentPlacement,
                    accentColor: tile.accentColor,
                    tileTint: tile.tileTintColor,
                    trend: trendInfo(for: statCard),
                    personalRecordLabel: statCard == .personalRecord ? logState.personalRecord?.exerciseName : nil
                )
                .frame(width: tileWidth, height: tileHeight)
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
        let bg: Color = tile.tileTintColor ?? Color(red: 0.96, green: 0.96, blue: 0.97)
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isBlankTile(tile) {
                handleBlankTileAction(tile)
            } else if tile.tileType == .shortcut {
                // Shortcut tiles deep-link directly into the item
                if tile.shortcutType == .workout, let itemID = tile.shortcutItemID {
                    workoutsState.pendingLaunchID = itemID
                    state.selectModule(ModuleIDs.workouts)
                } else if tile.shortcutType == .timer, let itemID = tile.shortcutItemID {
                    timerState.pendingLaunchID = itemID
                    state.selectModule(ModuleIDs.timer)
                } else if tile.shortcutType == .voiceTrainer, let itemID = tile.shortcutItemID {
                    voiceTrainerState.pendingLaunchID = itemID
                    state.selectModule(ModuleIDs.voiceTrainer)
                }
            } else if let targetID = findModuleID(for: tile) {
                state.selectModule(targetID)
            }
        }) {
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Image(systemName: tile.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.black)
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
                    if tile.targetModuleID == ModuleIDs.game1 {
                        Text("Level \(game1Level)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.bottom, 4)
                    } else if tile.targetModuleID == ModuleIDs.matchGame {
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
                .foregroundColor(.primary)

                // Accent bar overlay
                if tile.accentPlacement != .none {
                    AccentBarView(placement: tile.accentPlacement, color: tile.accentColor)
                }
            }
        }
        .frame(width: width, height: height)
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

    private var headerView: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 20) {
                headerImageView
                Text(headerState.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(headerState.textColor)
            }
            .padding(.horizontal, 4)
            Spacer(minLength: 0)
        }
        .frame(height: 72)
        .padding(.horizontal, 16)
        .background(headerBackgroundView)
    }

    // MARK: - Helper Methods
    
    private func findModuleID(for tile: DashboardTile) -> UUID? {
        // Prefer an explicit target when available
        if let targetID = tile.targetModuleID {
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
        case .game1:
            // Navigate to Game 1 module
            state.selectModule(ModuleIDs.game1)
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
                return String(format: "%.0f lbs", pr.weight)
            }
            return "—"
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

    private var headerImageView: some View {
        if let data = headerState.imageData, let uiImage = UIImage(data: data) {
            let image = Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
            return applyHeaderImageStyle(to: image)
        }
        let placeholder = Image(systemName: "dumbbell")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        return applyHeaderImageStyle(to: placeholder)
    }

    private func applyHeaderImageStyle<V: View>(to view: V) -> AnyView {
        let sized = view.frame(width: 64, height: 64)
        switch headerState.imageStyle {
        case .square:
            return AnyView(sized)
        case .rounded:
            return AnyView(sized.clipShape(RoundedRectangle(cornerRadius: 12)))
        case .circle:
            return AnyView(sized.clipShape(Circle()))
        }
    }
    
    private var headerBackgroundView: some View {
        Group {
            if headerState.backgroundUseGradient {
                LinearGradient(
                    colors: [headerState.backgroundColor, headerState.backgroundGradientSecondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                headerState.backgroundColor
            }
        }
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
            .filter { !existingTileModuleIDs.contains($0.id) && $0.displayName != "Dashboard" && $0.displayName != "Workout Buddy" && $0.displayName != "Workout Match" }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var statCardOptions: [StatCardType] {
        let used = Set(dashboardState.tiles.compactMap { $0.statCardType })
        return StatCardType.allCases.filter { !used.contains($0) }
    }

    private var hasSelection: Bool {
        !selectedModuleIDs.isEmpty || !selectedStatCards.isEmpty || selectedBlankIcon != nil
    }

    private func isMiniGameSelected() -> Bool {
        selectedBlankIcon != nil && (selectedBlankAction == .game1 || selectedBlankAction == .game2)
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
                                        .foregroundColor(.black)
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
                                            .foregroundColor(.black)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Mini Games") {
                    // Workout Buddy (formerly Game 1)
                    if let workoutBuddyModule = registry.registeredModules.first(where: { $0.displayName == "Workout Buddy" }) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if selectedModuleIDs.contains(workoutBuddyModule.id) {
                                selectedModuleIDs.remove(workoutBuddyModule.id)
                            } else {
                                selectedModuleIDs.insert(workoutBuddyModule.id)
                            }
                        }) {
                            HStack {
                                Text("Workout Buddy")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedModuleIDs.contains(workoutBuddyModule.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.black)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Workout Match
                    if let workoutMatchModule = registry.registeredModules.first(where: { $0.displayName == "Workout Match" }) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if selectedModuleIDs.contains(workoutMatchModule.id) {
                                selectedModuleIDs.remove(workoutMatchModule.id)
                            } else {
                                selectedModuleIDs.insert(workoutMatchModule.id)
                            }
                        }) {
                            HStack {
                                Text("Workout Match")
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedModuleIDs.contains(workoutMatchModule.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.black)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
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
                                            .foregroundColor(.black)
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
                                        .background(selectedBlankIcon == icon && !isMiniGameSelected() ? Color.black.opacity(0.15) : Color(red: 0.96, green: 0.96, blue: 0.97))
                                        .cornerRadius(8)
                                        .foregroundColor(.black)
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
                            let size: TileSize = (statCard == .workoutFrequency || statCard == .muscleGroupDistribution) ? .large : .small
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
                            if let module = moduleQuickOptions.first(where: { $0.id == moduleID }) {
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
    @Environment(\.dismiss) var dismiss
    
    let tile: DashboardTile
    
    @State private var title: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedSize: TileSize = .small
    
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
        if tile.tileType == .statCard,
           let statCard = tile.statCardType,
           (statCard == .workoutFrequency || statCard == .muscleGroupDistribution) {
            return [.large]
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
                                        .background(selectedIcon == icon ? Color.black.opacity(0.15) : Color(red: 0.96, green: 0.96, blue: 0.97))
                                        .cornerRadius(8)
                                        .foregroundColor(.black)
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
            }
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updatedTile = tile
                        updatedTile.title = title
                        updatedTile.icon = selectedIcon
                        updatedTile.size = selectedSize
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
    let trend: (symbol: String, color: Color)?
    let personalRecordLabel: String?   // exercise name for PR card

    var body: some View {
        let bg = tileTint ?? Color(red: 0.96, green: 0.96, blue: 0.97)
        ZStack(alignment: .leading) {
            VStack(spacing: 6) {
                // Header row: icon + title + trend arrow
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let t = trend {
                        Text(t.symbol)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(t.color)
                    }
                }

                Spacer().frame(height: 4)

                // Data / Content
                if statType == .workoutFrequency {
                    VStack(spacing: 4) {
                        Text(frequencyRangeLabel)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        WeekFrequencyView(days: frequencyDays)
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
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.black)
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
                                                    .font(.caption2)
                                                    .foregroundColor(.black)
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
                } else {
                    let isNumeric = statType == .totalWorkouts || statType == .dayStreaks
                        || statType == .totalTime || statType == .volumeThisWeek
                        || statType == .longestStreak || statType == .restDays
                    Text(value)
                        .font(.system(size: isNumeric ? 28 : 16, weight: .bold, design: isNumeric ? .rounded : .default))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)

                    // Secondary label for Personal Record card
                    if statType == .personalRecord, let exercise = personalRecordLabel {
                        Text(exercise)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))

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

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.label)
                        .font(.caption)
                        .foregroundColor(.gray)

                    Circle()
                        .stroke(Color.black, lineWidth: 1.5)
                        .background(
                            Circle().fill(day.hasWorkout ? Color.black : Color.clear)
                        )
                        .frame(width: 14, height: 14)
                }
            }
        }
        .frame(maxWidth: .infinity)
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

#Preview {
    DashboardModuleView(module: DashboardModule())
}
