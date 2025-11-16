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
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(speakerColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(speakerColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(formatSpeakerName(line.speakerId))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(speakerColor)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(formatTimestamp(line.startTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer()
                }

                Text(line.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var speakerColor: Color {
        let colors: [Color] = [
            .blue,
            .purple,
            .green,
            .orange,
            .pink,
            .cyan
        ]

        if line.speakerId.starts(with: "SPEAKER_") {
            let number = line.speakerId.replacingOccurrences(of: "SPEAKER_", with: "")
            if let num = Int(number), num > 0 {
                return colors[(num - 1) % colors.count]
            }
        }
        return .secondary
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
