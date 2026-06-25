////
////  MirrorLogView.swift
////  ExtendWatch
////
////  Wrist-side viewer for the in-app mirror log buffer. Lets the user
////  inspect what the watch saw during a phone-driven mirrored workout
////  handshake without needing a Mac + Console.app.
////

import SwiftUI

struct MirrorLogView: View {

    @State private var diagnostics = MirrorDiagnostics.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if diagnostics.lines.isEmpty {
                    Text("No entries yet. Start a workout from iPhone, then check back.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                } else {
                    ForEach(Array(diagnostics.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Mirror Log")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    diagnostics.clear()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { MirrorLogView() }
}
