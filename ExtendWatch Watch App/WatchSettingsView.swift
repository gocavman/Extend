////
////  WatchSettingsView.swift
////  ExtendWatch
////
////  Watch-native settings view for complication goals and per-complication
////  shape customization. All settings live in the App Group so complications
////  pick them up on the next timeline reload.
////

import SwiftUI
import WidgetKit

struct WatchSettingsView: View {

    @State private var stepsSettings: WatchStepsSettings = readWatchStepsSettings()
    @State private var shapes: WatchComplicationShapeSettings = readWatchComplicationShapeSettings()
    @State private var stepsGoalText: String = ""
    @State private var distanceGoalText: String = ""

    private let shapeOptions: [(label: String, symbol: String)] = [
        ("Ring",     ""),
        ("Circle",   "circle.fill"),
        ("Square",   "square.fill"),
        ("Heart",    "heart.fill"),
        ("Star",     "star.fill"),
        ("Hexagon",  "hexagon.fill"),
        ("Shield",   "shield.fill"),
        ("Seal",     "seal.fill"),
        ("Diamond",  "diamond.fill"),
        ("Triangle", "triangle.fill"),
        ("Pentagon", "pentagon.fill"),
        ("Octagon",  "octagon.fill")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Steps")
                        Spacer()
                        TextField("10000", text: $stepsGoalText)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: stepsGoalText) { _, newValue in
                                if let v = Double(newValue), v > 0 {
                                    stepsSettings.stepsGoal = v
                                    saveSteps()
                                }
                            }
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Distance")
                        Spacer()
                        HStack(spacing: 2) {
                            TextField("8.0", text: $distanceGoalText)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: distanceGoalText) { _, newValue in
                                    if let v = Double(newValue), v > 0 {
                                        stepsSettings.distanceGoal = v
                                        saveSteps()
                                    }
                                }
                            Text(stepsSettings.distanceUnit.rawValue)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .frame(width: 80)
                    }

                    Picker("Unit", selection: $stepsSettings.distanceUnit) {
                        ForEach(WatchDistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .onChange(of: stepsSettings.distanceUnit) { _, _ in saveSteps() }
                } header: {
                    Text("Goals")
                }

                Section {
                    shapeRow("Steps",            binding: $shapes.stepsShape)
                    shapeRow("Distance",         binding: $shapes.distanceShape)
                    shapeRow("Steps & Distance", binding: $shapes.stepsAndDistanceShape)
                    shapeRow("Water",            binding: $shapes.waterShape)
                    shapeRow("Today's Plan",     binding: $shapes.planShape)
                } header: {
                    Text("Complication Shape")
                }

                Section {
                    colorRow("Steps",            binding: $shapes.stepsColor)
                    colorRow("Distance",         binding: $shapes.distanceColor)
                    colorRow("Steps & Distance", binding: $shapes.stepsAndDistanceColor)
                    colorRow("Water",            binding: $shapes.waterColor)
                    colorRow("Today's Plan",     binding: $shapes.planColor)
                } header: {
                    Text("Complication Color")
                } footer: {
                    Text("\"Watch Face\" follows the watch face tint. Pick a specific color to override.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear { reloadFromStorage() }
    }

    private let colorOptions: [(label: String, key: String, color: Color?)] = [
        ("Watch Face", "",       nil),
        ("White",      "white",  .white),
        ("Orange",     "orange", .orange),
        ("Blue",       "blue",   .blue),
        ("Green",      "green",  .green),
        ("Pink",       "pink",   .pink)
    ]

    @ViewBuilder
    private func shapeRow(_ title: String, binding: Binding<String>) -> some View {
        Picker(title, selection: binding) {
            ForEach(shapeOptions, id: \.symbol) { option in
                if option.symbol.isEmpty {
                    Text(option.label).tag(option.symbol)
                } else {
                    HStack {
                        Image(systemName: option.symbol)
                        Text(option.label)
                    }
                    .tag(option.symbol)
                }
            }
        }
        .onChange(of: binding.wrappedValue) { _, _ in saveShapes() }
    }

    @ViewBuilder
    private func colorRow(_ title: String, binding: Binding<String>) -> some View {
        Picker(title, selection: binding) {
            ForEach(colorOptions, id: \.key) { option in
                HStack {
                    if let c = option.color {
                        Circle().fill(c).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "applewatch")
                    }
                    Text(option.label)
                }
                .tag(option.key)
            }
        }
        .onChange(of: binding.wrappedValue) { _, _ in saveShapes() }
    }

    private func reloadFromStorage() {
        stepsSettings = readWatchStepsSettings()
        shapes = readWatchComplicationShapeSettings()
        stepsGoalText = String(Int(stepsSettings.stepsGoal))
        let d = stepsSettings.distanceGoal
        distanceGoalText = d.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(d))
            : String(format: "%.1f", d)
    }

    private func saveSteps() {
        writeWatchStepsSettings(stepsSettings)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveShapes() {
        writeWatchComplicationShapeSettings(shapes)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    WatchSettingsView()
}
