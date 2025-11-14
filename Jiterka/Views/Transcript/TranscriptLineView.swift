//
//  TranscriptLineView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct TranscriptLineView: View {
    let line: SpeakerLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatSpeakerName(line.speakerId))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)

                Text(formatTimestamp(line.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Text(line.text)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(.horizontal)
    }

    private func formatSpeakerName(_ speakerId: String) -> String {
        if speakerId.starts(with: "SPEAKER_") {
            let number = speakerId.replacingOccurrences(of: "SPEAKER_", with: "")
            if let num = Int(number) {
                if num == 0 {
                    return "Unknown Speaker"
                }
                return "Speaker \(num)"
            }
        }
        return speakerId
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
