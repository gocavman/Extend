////
////  MirrorLogView.swift
////  Extend
////
////  iPhone-side viewer for the in-app mirror log buffer. Surfaces every
////  diagnostic line MirroredWorkoutCoordinator emits so we can debug a
////  failed phone → watch handshake without needing Console.app on a
////  paired Mac. Pair this with the wrist-side MirrorLogView to see both
////  ends of the conversation.
////

import SwiftUI

struct MirrorLogView: View {

    @State private var diagnostics = MirrorDiagnostics.shared
    @State private var showShare = false

    var body: some View {
        Group {
            if diagnostics.lines.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No entries yet")
                        .font(.headline)
                    Text("Start a workout on the iPhone. Lines appear here as the handshake with the Watch progresses.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(diagnostics.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Mirror Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(diagnostics.lines.isEmpty)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    diagnostics.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(diagnostics.lines.isEmpty)
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [diagnostics.exportText()])
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
