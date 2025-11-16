//
//  TranscriptView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct TranscriptView: View {
    let lines: [SpeakerLine]
    let speakerCount: Int

    init(transcript: ProcessedTranscript) {
        self.lines = transcript.lines
        self.speakerCount = transcript.speakerCount
    }

    init(lines: [SpeakerLine], speakerCount: Int) {
        self.lines = lines
        self.speakerCount = speakerCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }

                Text("\(speakerCount) speaker\(speakerCount == 1 ? "" : "s") detected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(lines) { line in
                    TranscriptLineView(line: line)
                }
            }
        }
    }
}
