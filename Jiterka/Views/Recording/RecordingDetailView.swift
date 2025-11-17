//
//  RecordingDetailView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import AppKit

struct RecordingDetailView: View {
    let recording: Recording
    @StateObject private var viewModel = RecordingDetailViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var selectedTab: Tab = .summary
    @State private var isHeaderExpanded = false

    enum Tab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
        case rawTranscript = "Raw Transcript"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                CollapsibleHeaderView(
                    recording: recording,
                    isSyncing: viewModel.isSyncing,
                    onSync: {
                        Task {
                            await viewModel.syncRecording(recording, modelContext: modelContext)
                        }
                    },
                    isExpanded: $isHeaderExpanded
                )

                Divider()

                tabBar

                Divider()
            }

            RecordingTabContentView(
                recording: recording,
                selectedTab: selectedTab
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await viewModel.regenerateTranscript(for: recording, modelContext: modelContext)
                    }
                } label: {
                    if viewModel.isRegenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRegenerating || recording.fileURL == nil)
                .help("Regenerate transcription and speaker diarization")
            }

            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete this recording")
            }
        }
        .confirmationDialog(
            "Delete Recording",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteRecording()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this recording? This action cannot be undone.")
        }
        .alert("Sync Failed", isPresented: .constant(viewModel.syncError != nil)) {
            Button("OK", role: .cancel) {
                viewModel.syncError = nil
            }
        } message: {
            if let error = viewModel.syncError {
                Text(error)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tabIcon(for: tab))
                                .font(.system(size: 14, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func deleteRecording() {
        if let fileURLPath = recording.fileURL {
            let fileURL = URL(fileURLWithPath: fileURLPath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("✅ Deleted audio file: \(fileURL.lastPathComponent)")
                } catch {
                    print("❌ Failed to delete audio file: \(error.localizedDescription)")
                }
            }
        }

        modelContext.delete(recording)
        dismiss()
    }

    private func tabIcon(for tab: Tab) -> String {
        switch tab {
        case .summary:
            return "doc.text.fill"
        case .transcript:
            return "sparkles.rectangle.stack.fill"
        case .rawTranscript:
            return "text.bubble.fill"
        }
    }
}
