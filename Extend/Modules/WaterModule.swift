////
////  WaterModule.swift
////  Extend
////
////  Water intake tracking module.
////

import SwiftUI

// MARK: - Module declaration

public struct WaterModule: AppModule {
    public let id: UUID = ModuleIDs.water
    public let displayName: String = "Water"
    public let iconName: String = "drop.fill"
    public let description: String = "Track daily water intake"

    public var order: Int = 5
    public var isVisible: Bool = true

    public var moduleView: AnyView {
        AnyView(WaterModuleView())
    }
}

// MARK: - Colors

private let waterBlue = Color(red: 0.2, green: 0.55, blue: 1.0)

// MARK: - Main module view

private struct WaterModuleView: View {
    @Environment(WaterState.self) var waterState
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var iPad: Bool { sizeClass == .regular }

    @State private var showHistory = false
    @State private var showGraphs  = false
    @State private var showCustomEntry = false
    @State private var customText  = ""
    @State private var animateFill = false
    @State private var fillFraction: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick-add grid (2 rows)
                quickAddGrid

                ScrollView {
                    VStack(spacing: 20) {
                        // Drop fill animation
                        dropFillView

                        // Today summary
                        todaySummary
                        
                        // Action buttons row
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationDestination(isPresented: $showHistory) {
                WaterHistorySheet()
                    .environment(waterState)
            }
            .navigationDestination(isPresented: $showGraphs) {
                WaterGraphsSheet()
                    .environment(waterState)
            }
        }
        .onAppear {
            updateFill(animated: false)
            if waterState.pendingOpenAddLog {
                waterState.pendingOpenAddLog = false
                showCustomEntry = true
            }
        }
        .onChange(of: waterState.pendingOpenAddLog) { _, newValue in
            if newValue {
                waterState.pendingOpenAddLog = false
                showCustomEntry = true
            }
        }
        .onChange(of: waterState.todayOz) { updateFill(animated: true) }
        .sheet(isPresented: $showCustomEntry) {
            WaterCustomEntrySheet(isPresented: $showCustomEntry)
                .environment(waterState)
        }
    }

    // MARK: - Quick-add grid (2 rows, all presets + custom visible without scrolling)

    private var quickAddGrid: some View {
        // Row 1: 4 oz, 6 oz, 8 oz   |  Row 2: 12 oz, 16 oz, Custom
        let presets = WaterQuickAdd.allCases   // [4, 6, 8, 12, 16]
        let row1 = Array(presets.prefix(3))
        let row2 = Array(presets.dropFirst(3))

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(row1, id: \.self) { preset in
                    quickAddCapsule(label: preset.label, filled: true) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        waterState.addOz(preset.rawValue)
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(row2, id: \.self) { preset in
                    quickAddCapsule(label: preset.label, filled: true) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        waterState.addOz(preset.rawValue)
                    }
                }
                // Custom button takes the last slot
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    customText = ""
                    showCustomEntry = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Custom")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(waterBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(waterBlue.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(waterBlue.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func quickAddCapsule(label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(waterBlue)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drop fill animation

    private var dropFillView: some View {
        let size: CGFloat = iPad ? 360 : 180
        return ZStack {
            // Background drop (empty portion) — same shape as the fill mask so edges align
            Image(systemName: "drop.fill")
                .font(.system(size: size))
                .foregroundColor(waterBlue.opacity(0.12))

            // Filled portion — rises from bottom
            GeometryReader { geo in
                let fillH = geo.size.height * fillFraction
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [waterBlue.opacity(0.7), waterBlue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: max(0, fillH))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .mask(
                Image(systemName: "drop.fill")
                    .font(.system(size: size))
                    .foregroundColor(.white)
            )
            .frame(width: size, height: size * 1.25)
            .animation(.easeInOut(duration: 0.8), value: fillFraction)

            // Percentage label
            VStack(spacing: 2) {
                Text("\(Int((fillFraction * 100).rounded()))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .frame(width: size, height: size * 1.25)
        .padding(.top, 8)
    }

    // MARK: - Today summary

    private var todaySummary: some View {
        let displayToday = waterState.unit.fromOz(waterState.todayOz)
        let displayGoal  = waterState.unit.fromOz(waterState.dailyGoalOz)
        let fmt: (Double) -> String = { v in
            if waterState.unit == .oz { return String(format: "%.0f", v) }
            return String(format: "%.0f", v)
        }

        return VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(fmt(displayToday))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(waterBlue)
                Text(waterState.unit.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Text("of \(fmt(displayGoal)) \(waterState.unit.rawValue) goal")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if waterState.currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text("\(waterState.currentStreak) day streak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showGraphs = true
            } label: {
                Label("Graphs", systemImage: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showHistory = true
            } label: {
                Label("History", systemImage: "clock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func updateFill(animated: Bool) {
        let target = waterState.todayFraction
        if animated {
            withAnimation(.easeInOut(duration: 0.8)) { fillFraction = target }
        } else {
            fillFraction = target
        }
    }
}

// MARK: - Custom entry sheet

private struct WaterCustomEntrySheet: View {
    @Environment(WaterState.self) var waterState
    @Binding var isPresented: Bool
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Amount", text: $text)
                            .keyboardType(.decimalPad)
                            .focused($focused)
                        Text(waterState.unit.rawValue)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Enter amount in \(waterState.unit.rawValue)")
                }
            }
            .navigationTitle("Custom Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let value = Double(text), value > 0 {
                            let oz = waterState.unit.toOz(value)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            waterState.addOz(oz)
                        }
                        isPresented = false
                    }
                    .disabled(Double(text) == nil || (Double(text) ?? 0) <= 0)
                }
            }
            .onAppear { focused = true }
        }
    }
}

// MARK: - History sheet

struct WaterHistorySheet: View {
    @Environment(WaterState.self) var waterState
    @Environment(\.dismiss) private var dismiss

    /// When set, filters to a single day and hides the range picker.
    var filterDate: Date? = nil

    @State private var selectedRange: WaterTimeRange = .week
    @State private var editingLog: WaterLog? = nil
    @State private var deletingLog: WaterLog? = nil
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Time range picker — hidden when showing a specific day
            if filterDate == nil {
                Picker("Range", selection: $selectedRange) {
                    ForEach(WaterTimeRange.allCases, id: \.self) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
            }

            if filteredLogs.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "drop")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary)
                    Text("No entries")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredLogs) { log in
                        WaterLogRow(log: log,
                                    onEdit: { editingLog = log },
                                    onDelete: { deletingLog = log; showDeleteConfirm = true })
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deletingLog = log; showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingLog = log
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Color(UIColor.systemGray))
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(filterDate.map { d in
            let f = DateFormatter(); f.dateFormat = "MMM d"; return "Water – \(f.string(from: d))"
        } ?? "Water History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if filterDate != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fullScreenCover(item: $editingLog) { log in
            WaterEditSheet(log: log)
                .environment(waterState)
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { deletingLog = nil }
            Button("Delete", role: .destructive) {
                if let log = deletingLog {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    waterState.deleteLog(id: log.id)
                }
                deletingLog = nil
            }
        } message: {
            Text("This will permanently delete this water entry.")
        }
    }

    private var filteredLogs: [WaterLog] {
        if let date = filterDate {
            return waterState.sortedLogs.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) }
        }
        let cutoff = selectedRange.cutoffDate
        return waterState.sortedLogs.filter { $0.loggedAt >= cutoff }
    }
}

private struct WaterLogRow: View {
    let log: WaterLog
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Environment(WaterState.self) var waterState

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            Image(systemName: "drop.fill")
                .foregroundColor(waterBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                let display = waterState.unit.fromOz(log.amountOz)
                let fmt = waterState.unit == .oz
                    ? String(format: "%.0f oz", display)
                    : String(format: "%.0f mL", display)
                Text(fmt)
                    .font(.system(size: 15, weight: .semibold))
                Text(Self.timeFormatter.string(from: log.loggedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !log.notes.isEmpty {
                    Text(log.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if onEdit != nil || onDelete != nil {
                HStack(spacing: 16) {
                    if let onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)
                    }
                    if let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct WaterEditSheet: View {
    @Environment(WaterState.self) var waterState
    @Environment(\.dismiss) var dismiss
    let log: WaterLog

    @State private var amountText: String = ""
    @State private var notes: String = ""
    @State private var loggedAt: Date = Date()
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(waterState.unit.rawValue)
                            .foregroundColor(.secondary)
                    }
                }
                Section("Date & Time") {
                    DatePicker("When", selection: $loggedAt)
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 22))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let v = Double(amountText), v > 0 {
                            var updated = log
                            updated.amountOz = waterState.unit.toOz(v)
                            updated.loggedAt = loggedAt
                            updated.notes = notes
                            waterState.updateLog(updated)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                amountText = String(format: "%.0f", waterState.unit.fromOz(log.amountOz))
                notes = log.notes
                loggedAt = log.loggedAt
            }
            .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Entry", role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    waterState.deleteLog(id: log.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }

    }
}

// MARK: - Graphs sheet

struct WaterGraphsSheet: View {
    @Environment(WaterState.self) var waterState
    @State private var selectedRange: WaterTimeRange = .week

    private var days: Int {
        switch selectedRange {
        case .week:        return 7
        case .month:       return 30
        case .threeMonths: return 90
        case .sixMonths:   return 180
        case .year:        return 365
        case .all:
            let cal = Calendar.current
            let earliest = waterState.logs.map { $0.loggedAt }.min() ?? Date()
            return max(1, cal.dateComponents([.day], from: cal.startOfDay(for: earliest), to: cal.startOfDay(for: Date())).day ?? 7)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Range", selection: $selectedRange) {
                ForEach(WaterTimeRange.allCases, id: \.self) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView {
                WaterDailyBarChartCard(days: days)
                    .environment(waterState)
                    .padding(16)
            }
        }
        .navigationTitle("Water Graphs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Daily bar chart card (reusable, also used by dashboard tile)

struct WaterDailyBarChartCard: View {
    @Environment(WaterState.self) var waterState
    let days: Int

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var iPad: Bool { sizeClass == .regular }

    var body: some View {
        let totals = waterState.dailyTotals(days: days)
        let maxOz = max(totals.map { $0.oz }.max() ?? waterState.dailyGoalOz, waterState.dailyGoalOz)
        let streak = waterState.currentStreak

        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(waterBlue)
                    .font(.system(size: iPad ? 18 : 13, weight: .semibold))
                Text("Last \(days) Days")
                    .font(.system(size: iPad ? 16 : 12, weight: .bold))
                Spacer()
            }

            // Bars
            WaterBarChartView(
                totals: totals,
                goalOz: waterState.dailyGoalOz,
                maxOz: maxOz,
                unit: waterState.unit
            )

            // Streak footer
            if streak > 0 {
                HStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.system(size: iPad ? 13 : 9, weight: .bold))
                        .foregroundColor(.orange)
                    Text("\(streak) day streak")
                        .font(.system(size: iPad ? 13 : 9))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Bar chart view

struct WaterBarChartView: View {
    let totals: [(date: Date, oz: Double)]
    let goalOz: Double
    let maxOz: Double
    let unit: WaterUnit

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var iPad: Bool { sizeClass == .regular }

    @State private var selectedIndex: Int? = nil

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    private static let tooltipFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        let barAreaH: CGFloat = iPad ? 140 : 80
        let labelH: CGFloat   = iPad ? 20 : 13
        let barSpacing: CGFloat = totals.count > 14 ? 3 : 5
        let fractions: [Double] = totals.map { maxOz > 0 ? $0.oz / maxOz : 0 }

        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                // Guard against zero/negative width during the first layout pass
                let availableWidth = max(geo.size.width, 1)
                let barWidth = max(
                    1,
                    (availableWidth - barSpacing * CGFloat(max(totals.count - 1, 0))) / CGFloat(max(totals.count, 1))
                )
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(Array(totals.enumerated()), id: \.offset) { idx, item in
                            let fraction = fractions[idx]
                            let barH = item.oz > 0 ? max(iPad ? 22 : 14, barAreaH * CGFloat(fraction)) : 0
                            let metGoal = item.oz >= goalOz
                            let isToday = Calendar.current.isDateInToday(item.date)
                            let isSelected = selectedIndex == idx
                            let hasSelection = selectedIndex != nil
                            let barOpacity: Double = hasSelection ? (isSelected ? 1.0 : 0.3) : 1.0
                            // Readability: white on full-blue bars, dark-blue on pale bars
                            let labelColor: Color = metGoal
                                ? .white
                                : (colorScheme == .dark
                                    ? Color(red: 0.85, green: 0.93, blue: 1.0)
                                    : Color(red: 0.08, green: 0.28, blue: 0.60))

                            VStack(spacing: 2) {
                                ZStack {
                                    if item.oz > 0 {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill((metGoal ? waterBlue : waterBlue.opacity(0.45)).opacity(barOpacity))
                                            .frame(height: barH)
                                        if barWidth > 18 {
                                            let display = unit.fromOz(item.oz)
                                            let label = String(format: "%.0f", display)
                                            Text(label)
                                                .font(.system(size: iPad ? 12 : 7, weight: .bold))
                                                .foregroundColor(labelColor)
                                                .minimumScaleFactor(0.5)
                                                .lineLimit(1)
                                                .opacity(barOpacity)
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(hasSelection && !isSelected ? 0.05 : 0.1))
                                            .frame(height: 3)
                                    }
                                }
                                .frame(height: barH > 0 ? barH : 3)

                                // Date label — show every other for dense charts
                                if totals.count <= 14 || idx % 2 == 0 {
                                    Text(isToday ? "Today" : Self.dayFormatter.string(from: item.date))
                                        .font(.system(size: iPad ? 11 : 7, weight: isSelected ? .bold : .regular))
                                        .foregroundColor(isSelected || isToday ? waterBlue : .gray)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .frame(width: barWidth)
                                        .frame(height: labelH)
                                } else {
                                    Color.clear.frame(width: barWidth, height: labelH)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Trend line overlay
                    WaterTrendLine(
                        fractions: fractions,
                        barWidth: barWidth,
                        barSpacing: barSpacing,
                        barAreaH: barAreaH,
                        labelH: labelH
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Goal line — dashed horizontal at the daily goal height
                    if maxOz > 0 && goalOz > 0 && goalOz <= maxOz {
                        let goalFraction = CGFloat(goalOz / maxOz)
                        let goalY = barAreaH * goalFraction + labelH / 2
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: availableWidth, y: 0))
                        }
                        .stroke(
                            waterBlue.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                        .offset(y: -goalY)
                        .allowsHitTesting(false)
                    }

                    // Gesture layer — covers bar area only (not label strip)
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity)
                        .frame(height: barAreaH)
                        .offset(y: -(labelH / 2))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let idx = Int(value.location.x / (barWidth + barSpacing))
                                    let clamped = max(0, min(totals.count - 1, idx))
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
                    if let idx = selectedIndex, idx < totals.count {
                        let item = totals[idx]
                        let fraction = fractions[idx]
                        let barH = item.oz > 0 ? max(iPad ? 22 : 14, barAreaH * CGFloat(fraction)) : CGFloat(0)
                        let barX = CGFloat(idx) * (barWidth + barSpacing)
                        let tipW: CGFloat = iPad ? 110 : 88
                        let tipH: CGFloat = iPad ? 44 : 34
                        let tipPad: CGFloat = 6
                        let rawX = barX + barWidth / 2
                        let clampedX = min(max(rawX, tipW / 2), availableWidth - tipW / 2)
                        let tipY = max(tipH / 2 + 2, barAreaH - barH - tipPad - tipH / 2)
                        let display = unit.fromOz(item.oz)
                        let valueText = item.oz > 0
                            ? String(format: "%.0f", display) + " \(unit.displayName)"
                            : "No data"
                        let dateText = Calendar.current.isDateInToday(item.date)
                            ? "Today"
                            : Self.tooltipFormatter.string(from: item.date)

                        VStack(spacing: 2) {
                            Text(valueText)
                                .font(.system(size: iPad ? 13 : 11, weight: .bold))
                                .foregroundColor(.primary)
                            Text(dateText)
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
            .frame(maxWidth: .infinity)
            .frame(height: barAreaH + labelH)

            // Legend
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(waterBlue)
                    .frame(width: 12, height: 8)
                Text("Met goal")
                    .font(.system(size: iPad ? 12 : 8))
                    .foregroundColor(.gray)
                RoundedRectangle(cornerRadius: 2)
                    .fill(waterBlue.opacity(0.45))
                    .frame(width: 12, height: 8)
                Text("Below goal")
                    .font(.system(size: iPad ? 12 : 8))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Trend line (Catmull-Rom smooth curve, matches VolumeBarChartView style)

private struct WaterTrendLine: View {
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
                    let clamped: CGFloat = max(14.0 / barAreaH, CGFloat(fractions[i]))
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
            // Glow + line
            ctx.stroke(path, with: .color(Color(red: 0.2, green: 0.55, blue: 1.0).opacity(0.15)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            ctx.stroke(path, with: .color(Color(red: 0.2, green: 0.55, blue: 1.0).opacity(0.65)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            // Dots at each data point
            for (i, pt) in pts.enumerated() {
                guard fractions[i] > 0 else { continue }
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
                         with: .color(Color(red: 0.2, green: 0.55, blue: 1.0).opacity(0.75)))
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 1.5, y: pt.y - 1.5, width: 3, height: 3)),
                         with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Time range enum

enum WaterTimeRange: String, CaseIterable {
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
}
