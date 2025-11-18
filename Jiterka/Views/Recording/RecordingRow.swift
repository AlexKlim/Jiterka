//
//  RecordingRow.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI
import SwiftData

struct RecordingRow: View {
    let recording: Recording
    let isSelected: Bool

    @StateObject private var syncCoordinator = SyncCoordinator.shared

    private var isProcessing: Bool {
        let isSyncing = syncCoordinator.isSyncingRecording(recording.id)
        let isTranscribing = !recording.isTranscribed || !recording.isSummarized

        return isSyncing || isTranscribing
    }

    private var shouldShowLoadingIndicator: Bool {
        return isProcessing && !isSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)

            HStack {
                Text(recording.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if shouldShowLoadingIndicator {
                    ProcessingIndicator()
                }

                Text(formatDuration(recording.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
