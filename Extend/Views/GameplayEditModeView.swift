import SwiftUI

/// Edit mode controls for the gameplay stick figure editor
struct GameplayEditModeView: View {
    @State private var figureScale: CGFloat = 1.0
    @State private var strokeThicknessMultiplier: CGFloat = 1.0
    @State private var fusiformUpperTorso: CGFloat = 4.0
    @State private var fusiformLowerTorso: CGFloat = 4.0
    @State private var fusiformUpperArms: CGFloat = 2.0
    @State private var fusiformLowerArms: CGFloat = 3.0
    @State private var fusiformUpperLegs: CGFloat = 4.0
    @State private var fusiformLowerLegs: CGFloat = 4.0
    @State private var showGrid: Bool = true
    @State private var showJoints: Bool = true
    @State private var positionX: CGFloat = 0
    @State private var positionY: CGFloat = 0
    
    @State private var showSavePanel: Bool = false
    @State private var showLoadPanel: Bool = false
    
    var onClose: () -> Void
    var onValuesChanged: (EditModeValues) -> Void
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.95, green: 0.95, blue: 0.98).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Text("EDIT MODE")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: onClose) {
                        Text("✕")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .padding(.trailing, 16)
                }
                .padding(.vertical, 12)
                .background(Color(red: 0.2, green: 0.4, blue: 0.2))
                .foregroundColor(.white)
                
                // Bottom controls panel (scrollable)
                ScrollView {
                    VStack(spacing: 12) {
                        // Figure Scale with +/- buttons
                        sliderWithButtons(
                            label: "Figure Scale",
                            value: $figureScale,
                            range: 0.5...2.0,
                            step: 0.1
                        )
                        
                        // Stroke Thickness with +/- buttons
                        sliderWithButtons(
                            label: "Stroke Thickness",
                            value: $strokeThicknessMultiplier,
                            range: 0.5...2.0,
                            step: 0.1
                        )
                        
                        // Fusiform section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FUSIFORM")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            sliderWithButtons(label: "Upper Torso", value: $fusiformUpperTorso, range: 0...10, step: 1)
                            sliderWithButtons(label: "Lower Torso", value: $fusiformLowerTorso, range: 0...10, step: 1)
                            sliderWithButtons(label: "Upper Arms", value: $fusiformUpperArms, range: 0...10, step: 1)
                            sliderWithButtons(label: "Lower Arms", value: $fusiformLowerArms, range: 0...10, step: 1)
                            sliderWithButtons(label: "Upper Legs", value: $fusiformUpperLegs, range: 0...10, step: 1)
                            sliderWithButtons(label: "Lower Legs", value: $fusiformLowerLegs, range: 0...10, step: 1)
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(4)
                        
                        // Display Options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DISPLAY OPTIONS")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Toggle("Show Grid", isOn: $showGrid)
                                .onChange(of: showGrid) { updateValues() }
                            
                            Toggle("Show Interactive Joints", isOn: $showJoints)
                                .onChange(of: showJoints) { updateValues() }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(4)
                        
                        // Save/Load Buttons
                        VStack(spacing: 8) {
                            Button(action: { showSavePanel = true }) {
                                Text("SAVE FRAME")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.2, green: 0.6, blue: 0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            
                            Button(action: { showLoadPanel = true }) {
                                Text("LOAD FRAME")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.2, green: 0.4, blue: 0.6))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(4)
                    }
                    .padding(12)
                }
            }
        }
        .sheet(isPresented: $showSavePanel) {
            SaveFrameDialog(isPresented: $showSavePanel, editValues: getCurrentEditValues())
        }
        .sheet(isPresented: $showLoadPanel) {
            LoadFrameDialog(isPresented: $showLoadPanel)
        }
    }
    
    private func sliderWithButtons(
        label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
            
            HStack(spacing: 8) {
                // Minus button
                Button(action: {
                    let newValue = max(range.lowerBound, value.wrappedValue - step)
                    value.wrappedValue = newValue
                    updateValues()
                }) {
                    Text("−")
                        .frame(width: 32, height: 32)
                        .background(Color(red: 0.9, green: 0.9, blue: 0.9))
                        .cornerRadius(4)
                }
                
                // Slider
                Slider(value: value, in: range)
                    .onChange(of: value.wrappedValue) { updateValues() }
                
                // Value display
                Text(String(format: step < 1 ? "%.2f" : "%.0f", value.wrappedValue))
                    .frame(width: 40)
                    .font(.caption)
                
                // Plus button
                Button(action: {
                    let newValue = min(range.upperBound, value.wrappedValue + step)
                    value.wrappedValue = newValue
                    updateValues()
                }) {
                    Text("+")
                        .frame(width: 32, height: 32)
                        .background(Color(red: 0.9, green: 0.9, blue: 0.9))
                        .cornerRadius(4)
                }
            }
        }
    }
    
    private func updateValues() {
        let values = getCurrentEditValues()
        onValuesChanged(values)
    }
    
    private func getCurrentEditValues() -> EditModeValues {
        return EditModeValues(
            figureScale: figureScale,
            fusiformUpperTorso: fusiformUpperTorso,
            fusiformLowerTorso: fusiformLowerTorso,
            fusiformUpperArms: fusiformUpperArms,
            fusiformLowerArms: fusiformLowerArms,
            fusiformUpperLegs: fusiformUpperLegs,
            fusiformLowerLegs: fusiformLowerLegs,
            fusiformShoulders: nil,
            fusiformDeltoids: nil,
            peakPositionUpperArms: nil,
            peakPositionLowerArms: nil,
            peakPositionUpperLegs: nil,
            peakPositionLowerLegs: nil,
            peakPositionUpperTorso: nil,
            peakPositionLowerTorso: nil,
            peakPositionDeltoids: nil,
            skeletonSizeTorso: nil,
            skeletonSizeArm: nil,
            skeletonSizeLeg: nil,
            jointShapeSize: nil,
            shoulderWidthMultiplier: nil,
            waistWidthMultiplier: nil,
            waistThicknessMultiplier: nil,
            neckLength: nil,
            neckWidth: nil,
            handSize: nil,
            footSize: nil,
            strokeThicknessJoints: nil,
            strokeThicknessUpperTorso: nil,
            strokeThicknessLowerTorso: nil,
            strokeThicknessUpperArms: nil,
            strokeThicknessLowerArms: nil,
            strokeThicknessUpperLegs: nil,
            strokeThicknessLowerLegs: nil,
            strokeThicknessFullTorso: nil,
            strokeThicknessDeltoids: nil,
            showGrid: showGrid,
            showJoints: showJoints,
            positionX: positionX,
            positionY: positionY,
            bodyPartColors: nil,
            showInteractiveJoints: nil
        )
    }
}

/// Data structure for edit mode values
struct EditModeValues {
    let figureScale: CGFloat
    let fusiformUpperTorso: CGFloat
    let fusiformLowerTorso: CGFloat
    let fusiformUpperArms: CGFloat
    let fusiformLowerArms: CGFloat
    let fusiformUpperLegs: CGFloat
    let fusiformLowerLegs: CGFloat
    let fusiformShoulders: CGFloat?
    let fusiformDeltoids: CGFloat?
    let peakPositionUpperArms: CGFloat?
    let peakPositionLowerArms: CGFloat?
    let peakPositionUpperLegs: CGFloat?
    let peakPositionLowerLegs: CGFloat?
    let peakPositionUpperTorso: CGFloat?
    let peakPositionLowerTorso: CGFloat?
    let peakPositionDeltoids: CGFloat?
    let skeletonSizeTorso: CGFloat?
    let skeletonSizeArm: CGFloat?
    let skeletonSizeLeg: CGFloat?
    let jointShapeSize: CGFloat?
    let shoulderWidthMultiplier: CGFloat?
    let waistWidthMultiplier: CGFloat?
    let waistThicknessMultiplier: CGFloat?
    let neckLength: CGFloat?
    let neckWidth: CGFloat?
    let handSize: CGFloat?
    let footSize: CGFloat?
    let strokeThicknessJoints: CGFloat?
    let strokeThicknessUpperTorso: CGFloat?
    let strokeThicknessLowerTorso: CGFloat?
    let strokeThicknessUpperArms: CGFloat?
    let strokeThicknessLowerArms: CGFloat?
    let strokeThicknessUpperLegs: CGFloat?
    let strokeThicknessLowerLegs: CGFloat?
    let strokeThicknessFullTorso: CGFloat?
    let strokeThicknessDeltoids: CGFloat?
    let showGrid: Bool
    let showJoints: Bool
    let positionX: CGFloat
    let positionY: CGFloat
    let bodyPartColors: [String: UIColor]?
    let showInteractiveJoints: Bool?
}

/// Save frame dialog
struct SaveFrameDialog: View {
    @Binding var isPresented: Bool
    let editValues: EditModeValues
    @State private var frameName: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Save Frame")
                    .font(.headline)
                    .padding()
                
                TextField("Frame name", text: $frameName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    
                    Button("Save") {
                        saveFrame()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(frameName.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .disabled(frameName.isEmpty)
                }
                .padding()
                
                Spacer()
            }
        }
    }
    
    private func saveFrame() {
        guard !frameName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Frame name cannot be empty"
            showError = true
            return
        }
        
        let savedFrame = SavedEditFrame(name: frameName, from: editValues)
        SavedFramesManager.shared.saveFrame(savedFrame)
        
        isPresented = false
    }
}

/// Load frame dialog
struct LoadFrameDialog: View {
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    @State private var savedFrames: [SavedEditFrame] = []
    @State private var showCopyAlert: Bool = false
    @State private var copiedFrameName: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("Load Frame")
                    .font(.headline)
                    .padding()
                
                SearchBar(text: $searchText)
                    .padding()
                
                if savedFrames.isEmpty {
                    VStack {
                        Text("No saved frames")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredFrames, id: \.id) { frame in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(frame.name)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    Text(formatDate(frame.timestamp))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                // Copy button - visible and clickable
                                Button(action: {
                                    copyFrameToClipboard(frame)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                        .padding(8)
                                }
                                .buttonStyle(.plain)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteFrame(frame.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Close") {
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
                .padding()
            }
            .alert("Copied to Clipboard", isPresented: $showCopyAlert) {
                Button("OK") { showCopyAlert = false }
            } message: {
                Text("\(copiedFrameName) JSON has been copied to your clipboard")
            }
        }
        .onAppear {
            loadSavedFrames()
        }
    }
    
    private var filteredFrames: [SavedEditFrame] {
        if searchText.isEmpty {
            return savedFrames
        }
        return savedFrames.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func loadSavedFrames() {
        savedFrames = SavedFramesManager.shared.getAllFrames()
    }
    
    private func deleteFrame(_ id: UUID) {
        SavedFramesManager.shared.deleteFrame(id: id)
        loadSavedFrames()
    }
    
    private func copyFrameToClipboard(_ frame: SavedEditFrame) {
        if let jsonString = SavedFramesManager.shared.exportFrameAsJSON(frame: frame) {
            UIPasteboard.general.string = jsonString
            copiedFrameName = frame.name
            showCopyAlert = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Simple search bar component
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search frames", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    GameplayEditModeView(
        onClose: { print("Close") },
        onValuesChanged: { _ in print("Values changed") }
    )
}

