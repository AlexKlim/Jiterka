//
//  RecordingHeaderView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct RecordingHeaderView: View {
    let recording: Recording

    var body: some View {
        VStack(spacing: 12) {
            Text(recording.name)
                .font(.title)
                .fontWeight(.bold)

            Text(recording.timestamp.formatted(date: .long, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formatDuration(recording.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d hours, %d minutes, %d seconds", hours, minutes, seconds)
        } else {
            return String(format: "%d minutes, %d seconds", minutes, seconds)
        }
    }
}
