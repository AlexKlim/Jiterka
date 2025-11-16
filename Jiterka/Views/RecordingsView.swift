//
//  ContentView.swift
//  Jiterka
//
//  Created by Alex K on 11/12/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

struct RecordingsView: View {
    @StateObject private var recordingManager = ScreenCaptureAudioManager()
    @StateObject private var transcriptProcessor = TranscriptProcessor()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.timestamp, order: .reverse) private var recordings: [Recording]
    @State private var selectedRecording: Recording?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedRecording) {
                Section("Recordings") {
                    ForEach(recordings) { recording in
                        NavigationLink(value: recording) {
                            RecordingRow(recording: recording)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteRecording(recording)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    #if os(iOS)
                    .onDelete(perform: deleteRecordings)
                    #endif
                }
            }
            .navigationTitle("Jiterka")
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        selectedRecording = nil
                    } label: {
                        Label("New Recording", systemImage: "plus")
                    }
                    .help("Start new recording")
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        if let path = recordingManager.getRecordingsDirectoryPath() {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                        }
                    } label: {
                        Label("Show Recordings Folder", systemImage: "folder")
                    }
                    .help("Open recordings folder in Finder")
                }
            }
        } detail: {
            if let recording = selectedRecording {
                RecordingDetailView(recording: recording)
            } else {
                RecordingControlsView(
                    recordingManager: recordingManager,
                    onStopRecording: saveRecording
                )
            }
        }
    }

    private func saveRecording() async {
        guard let audioURL = recordingManager.lastRecordingURL else { return }

        let asset = AVURLAsset(url: audioURL)
        let duration: TimeInterval
        do {
            let assetDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(assetDuration)
        } catch {
            print("Failed to load audio duration: \(error.localizedDescription)")
            duration = 0
        }

        let timestamp = Date()
        let recording = Recording(
            timestamp: timestamp,
            duration: duration,
            name: timestamp.formatted(date: .abbreviated, time: .shortened),
            fileURL: audioURL.path
        )
        modelContext.insert(recording)

        Task {
            await transcribeRecording(recording, audioURL: audioURL)
        }
    }

    private func transcribeRecording(_ recording: Recording, audioURL: URL) async {
        guard #available(macOS 26.0, *) else {
            recording.isTranscribed = true
            try? modelContext.save()
            print("⚠️ Transcription requires macOS 26.0 or later")
            return
        }

        do {
            let transcript = try await transcriptProcessor.processAudio(url: audioURL)
            recording.transcript = transcript
            try? modelContext.save()

            if JiteraBoostConfig.isConfigured {
                do {
                    let summary = try await transcriptProcessor.generateSummary(for: transcript)
                    recording.summary = summary
                    recording.isSummarized = true
                    try? modelContext.save()
                    print("✅ Summary generated successfully")
                } catch {
                    print("❌ Failed to generate summary: \(error.localizedDescription)")
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
            print("❌ Failed to transcribe recording: \(error.localizedDescription)")
        }
    }

    private func deleteRecording(_ recording: Recording) {
        withAnimation {
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
        }
    }

    #if os(iOS)
    private func deleteRecordings(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                deleteRecording(recordings[index])
            }
        }
    }
    #endif
}

#Preview {
    RecordingsView()
        .modelContainer(for: Recording.self, inMemory: true)
}
