//
//  RecordingDetailViewModel.swift
//  Jiterka
//
//  Business logic for recording detail view
//

import Foundation
import SwiftData
import Combine

class RecordingDetailViewModel: ObservableObject {
    @Published var isRegenerating = false
    @Published var isSyncing = false
    @Published var syncError: String?

    private let transcriptProcessor = TranscriptProcessor()

    @MainActor
    func regenerateTranscript(for recording: Recording, modelContext: ModelContext) async {
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

    @MainActor
    func syncRecording(_ recording: Recording, modelContext: ModelContext) async {
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
}
