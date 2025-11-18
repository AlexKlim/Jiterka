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
    @Published var syncMessages: [SyncMessage] = []
    @Published var syncRecordingName: String = ""
    @Published var syncRecordingDate: Date = Date()

    private let transcriptProcessor = TranscriptProcessor()

    private func addMessage(_ text: String, type: SyncMessage.MessageType, aiResponse: String? = nil) {
        let message = SyncMessage(
            timestamp: Date(),
            text: text,
            type: type,
            aiResponse: aiResponse
        )
        syncMessages.append(message)
    }

    private func updateLastMessage(type: SyncMessage.MessageType, aiResponse: String? = nil) {
        guard let lastIndex = syncMessages.indices.last else { return }
        var updatedMessage = syncMessages[lastIndex]
        updatedMessage.type = type
        if let aiResponse = aiResponse {
            updatedMessage.aiResponse = aiResponse
        }
        syncMessages[lastIndex] = updatedMessage
    }

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
            addMessage("Sync failed: Summary and transcript are required", type: .error)
            return
        }

        guard SyncCoordinator.shared.canStartSync(for: recording.id) else {
            syncError = "Another recording is currently syncing. Please wait."
            addMessage("Another recording is currently syncing", type: .error)
            return
        }
    
        syncRecordingName = recording.name
        syncRecordingDate = recording.timestamp
        
        syncMessages.removeAll()
        isSyncing = true
        syncError = nil
        SyncCoordinator.shared.startSync(for: recording.id)

        defer {
            isSyncing = false
            SyncCoordinator.shared.endSync(for: recording.id)
        }

        addMessage("Starting sync to Jitera...", type: .info)

        do {
            let result = try await transcriptProcessor.syncToJitera(
                name: recording.name,
                date: recording.timestamp,
                summary: summary,
                transcript: transcript,
                onProgress: { [weak self] (message: String) in
                    guard let self = self else { return }                    
                    if message.hasPrefix("✅") {
                        self.updateLastMessage(type: .success)
                    } else {
                        self.addMessage(message, type: .inProgress)
                    }
                }
            )

            if result.success {
                recording.isSynced = true
                try? modelContext.save()
                addMessage("Sync completed successfully", type: .success, aiResponse: result.aiResponse)
            } else {
                syncError = result.message
                addMessage("Sync failed: \(result.message)", type: .error, aiResponse: result.aiResponse)
            }
        } catch {
            syncError = error.localizedDescription
            addMessage("Sync failed: \(error.localizedDescription)", type: .error)
        }
    }
}
