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
    @State private var selectedTab: Tab = .summary

    enum Tab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    RecordingHeaderView(recording: recording)

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
                                Image(systemName: tab == .summary ? "doc.text.fill" : "text.bubble.fill")
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
                if selectedTab == .summary {
                    if let transcript = recording.transcript {
                        SummaryView(summary: recording.summary)
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
                } else {
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
            recording.isTranscribed = false
            try? modelContext.save()
            
            let transcript = try await transcriptProcessor.processAudio(url: audioURL)

            recording.transcript = transcript
            try? modelContext.save()

            print("✅ Transcription regenerated successfully")
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

}
