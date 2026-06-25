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
    @State private var pages: WatchPageVisibility = readWatchPageVisibility()
    @State private var stepsGoalText: String = ""
    @State private var distanceGoalText: String = ""
    /// Voice countdown during workouts (read by WatchWorkoutRunnerView).
    @AppStorage("watch_speech_enabled") private var speechEnabled: Bool = true

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
                    Toggle("Today's Plan", isOn: $pages.showPlan)
                        .onChange(of: pages.showPlan) { _, _ in savePages() }
                    Toggle("Library", isOn: $pages.showLibrary)
                        .onChange(of: pages.showLibrary) { _, _ in savePages() }
                    Toggle("Steps & Distance", isOn: $pages.showSteps)
                        .onChange(of: pages.showSteps) { _, _ in savePages() }
                    Toggle("Water", isOn: $pages.showWater)
                        .onChange(of: pages.showWater) { _, _ in savePages() }
                } header: {
                    Text("Pages")
                } footer: {
                    Text("Hidden pages won't appear when swiping. Settings is always shown.")
                        .font(.caption2)
                }

                Section {
                    Toggle("Voice Countdown", isOn: $speechEnabled)
                } header: {
                    Text("Workouts")
                } footer: {
                    Text("Speaks the last 5 seconds of timed sets and announces complex rounds.")
                        .font(.caption2)
                }

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
                        TextField("8.0", text: $distanceGoalText)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: distanceGoalText) { _, newValue in
                                if let v = Double(newValue), v > 0 {
                                    stepsSettings.distanceGoal = v
                                    saveSteps()
                                }
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
                    shapeRow("Library",          binding: $shapes.libraryShape)
                } header: {
                    Text("Complication Shape")
                }

                Section {
                    colorRow("Steps",            binding: $shapes.stepsColor)
                    colorRow("Distance",         binding: $shapes.distanceColor)
                    colorRow("Steps & Distance", binding: $shapes.stepsAndDistanceColor)
                    colorRow("Water",            binding: $shapes.waterColor)
                    colorRow("Today's Plan",     binding: $shapes.planColor)
                    colorRow("Library",          binding: $shapes.libraryColor)
                } header: {
                    Text("Complication Color")
                } footer: {
                    Text("\"Watch Face\" follows the watch face tint. Pick a specific color to override.")
                        .font(.caption2)
                }

                Section {
                    colorRow("Steps",            binding: $shapes.stepsTextColor)
                    colorRow("Distance",         binding: $shapes.distanceTextColor)
                    colorRow("Steps & Distance", binding: $shapes.stepsAndDistanceTextColor)
                    colorRow("Water",            binding: $shapes.waterTextColor)
                    colorRow("Today's Plan",     binding: $shapes.planTextColor)
                    colorRow("Library",          binding: $shapes.libraryTextColor)
                } header: {
                    Text("Complication Text Color")
                } footer: {
                    Text("Color of the value shown in the middle. \"Watch Face\" follows the shape color.")
                        .font(.caption2)
                }

                Section {
                    NavigationLink("Mirror Log") { MirrorLogView() }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionLabel())
                            .foregroundColor(.secondary)
                            .font(.system(size: 11).monospacedDigit())
                    }
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("Confirm this matches the iPhone build before debugging a mirrored workout handshake.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear { reloadFromStorage() }
    }

    /// "v1.2.3 (45)" pulled from the bundle so the user can confirm the
    /// wrist app and the phone app are on the same build before diagnosing.
    private func versionLabel() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "v\(short) (\(build))"
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
        pages = readWatchPageVisibility()
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

    private func savePages() {
        writeWatchPageVisibility(pages)
        NotificationCenter.default.post(name: .watchPageVisibilityChanged, object: nil)
    }
}

#Preview {
    WatchSettingsView()
}
