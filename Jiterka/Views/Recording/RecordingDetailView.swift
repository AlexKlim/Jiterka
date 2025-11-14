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

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                RecordingHeaderView(recording: recording)

                if recording.fileURL != nil {
                    AudioPlayerView(playerManager: playerManager)
                }

                if let transcript = recording.transcript {
                    TranscriptView(transcript: transcript)
                } else if recording.isTranscribed {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Transcription failed")
                            .font(.headline)
                        Text("No speech detected in this recording")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Processing transcription...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding(.bottom)
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
