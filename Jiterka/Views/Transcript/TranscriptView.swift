//
//  TranscriptView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct TranscriptView: View {
    let transcript: ProcessedTranscript

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcript")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.secondary)
                Text("\(transcript.speakerCount) speaker(s) detected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                ForEach(transcript.lines) { line in
                    TranscriptLineView(line: line)
                }
            }
        }
        .padding(.vertical)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
