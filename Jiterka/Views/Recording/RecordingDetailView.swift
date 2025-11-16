//
//  RecordingDetailView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct RecordingDetailView: View {
    let recording: Recording
    @StateObject private var playerManager = AudioPlayerManager()
    @StateObject private var transcriptProcessor = TranscriptProcessor()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isRegenerating = false
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var selectedTab: Tab = .summary

    enum Tab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
        case rawTranscript = "Raw Transcript"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    RecordingHeaderView(
                        recording: recording,
                        isSyncing: isSyncing,
                        onSync: {
                            Task {
                                await syncRecording()
                            }
                        }
                    )

                    if recording.fileURL != nil {
                        AudioPlayerView(playerManager: playerManager)
                    }
                }
                .padding(20)
            }
            .background(Color(NSColor.windowBackgroundColor))

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
            .overlay(alignment: .bottom) {
                Divider()
            }

            Group {
                switch selectedTab {
                case .summary:
                    if recording.transcript != nil {
                        if recording.isSummarized {
                            SummaryView(summary: recording.summary)
                        } else {
                            ProcessingStateView(message: "Generating summary...")
                        }
                    } else if recording.isTranscribed {
                        EmptyStateView(
                            icon: "exclamationmark.triangle.fill",
                            title: "Transcription Failed",
                            message: "No summary available without transcription",
                            iconColor: .orange
                        )
                    } else {
                        ProcessingStateView(message: "Processing transcription...")
                    }

                case .transcript:
                    if let transcript = recording.transcript {
                        if let cleanedLines = transcript.cleanedLines, !cleanedLines.isEmpty {
                            ScrollView {
                                TranscriptView(
                                    lines: cleanedLines,
                                    speakerCount: transcript.speakerCount
                                )
                                .padding(20)
                            }
                        } else if let cleanupError = transcript.cleanupError {
                            EmptyStateView(
                                icon: "exclamationmark.triangle.fill",
                                title: "AI Cleanup Failed",
                                message: "JiteraBoost could not clean up the transcript: \(cleanupError)\n\nView the raw transcript instead.",
                                iconColor: .orange
                            )
                        } else {
                            ScrollView {
                                TranscriptView(transcript: transcript)
                                    .padding(20)
                            }
                        }
                    } else if recording.isTranscribed {
                        EmptyStateView(
                            icon: "exclamationmark.triangle.fill",
                            title: "Transcription Failed",
                            message: "No speech detected in this recording",
                            iconColor: .orange
                        )
                    } else {
                        ProcessingStateView(message: "Processing transcription...")
                    }

                case .rawTranscript:
                    if let transcript = recording.transcript {
                        ScrollView {
                            TranscriptView(transcript: transcript)
                                .padding(20)
                        }
                    } else if recording.isTranscribed {
                        EmptyStateView(
                            icon: "exclamationmark.triangle.fill",
                            title: "Transcription Failed",
                            message: "No speech detected in this recording",
                            iconColor: .orange
                        )
                    } else {
                        ProcessingStateView(message: "Processing transcription...")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await regenerateTranscript()
                    }
                } label: {
                    if isRegenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRegenerating || recording.fileURL == nil)
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
        .alert("Sync Failed", isPresented: .constant(syncError != nil)) {
            Button("OK", role: .cancel) {
                syncError = nil
            }
        } message: {
            if let error = syncError {
                Text(error)
            }
        }
        .onAppear {
            loadRecordingAudio()
        }
        .onChange(of: recording.id) {
            loadRecordingAudio()
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }

    private func regenerateTranscript() async {
        guard let fileURLPath = recording.fileURL else { return }

        let audioURL = URL(fileURLWithPath: fileURLPath)
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file not found")
            return
        }

        guard #available(macOS 26.0, *) else {
            print("⚠️ Transcription requires macOS 26.0 or later")
            return
        }

        isRegenerating = true
        defer { isRegenerating = false }

        print("🔄 Regenerating transcription and diarization for: \(audioURL.lastPathComponent)")

        do {
            recording.transcript = nil
            recording.summary = nil
            recording.isTranscribed = false
            recording.isSummarized = false
            recording.isSynced = false
            try? modelContext.save()

            let transcript = try await transcriptProcessor.processAudio(url: audioURL)

            recording.transcript = transcript
            try? modelContext.save()

            print("✅ Transcription regenerated successfully")

            if JiteraBoostConfig.isConfigured {
                do {
                    let summary = try await transcriptProcessor.generateSummary(for: transcript)
                    recording.summary = summary
                    recording.isSummarized = true
                    try? modelContext.save()
                    print("✅ Summary regenerated successfully")
                } catch {
                    print("❌ Failed to regenerate summary: \(error.localizedDescription)")
                    recording.isSummarized = true
                    try? modelContext.save()
                }
            } else {
                print("⚠️ JiteraBoost not configured - skipping summary generation")
                recording.isSummarized = true
                try? modelContext.save()
            }
        } catch {
            recording.isTranscribed = true
            try? modelContext.save()
            print("❌ Failed to regenerate transcription: \(error.localizedDescription)")
        }
    }

    private func loadRecordingAudio() {
        playerManager.cleanup()

        if let fileURLPath = recording.fileURL {
            let fileURL = URL(fileURLWithPath: fileURLPath)
            playerManager.loadAudio(from: fileURL)
        }
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

    private func syncRecording() async {
        guard let summary = recording.summary,
              let transcript = recording.transcript else {
            syncError = "Summary and transcript are required for sync"
            return
        }

        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let result = try await transcriptProcessor.syncToJitera(
                name: recording.name,
                date: recording.timestamp,
                summary: summary,
                transcript: transcript
            )

            if result.success {
                recording.isSynced = true
                try? modelContext.save()
            } else {
                syncError = result.message
            }
        } catch {
            syncError = error.localizedDescription
        }
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
