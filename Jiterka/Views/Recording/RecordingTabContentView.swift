//
//  RecordingTabContentView.swift
//  Jiterka
//
//  Tab content rendering for recording detail view
//

import SwiftUI

struct RecordingTabContentView: View {
    let recording: Recording
    let selectedTab: RecordingDetailView.Tab

    var body: some View {
        Group {
            switch selectedTab {
            case .summary:
                summaryContent

            case .transcript:
                transcriptContent

            case .rawTranscript:
                rawTranscriptContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    @ViewBuilder
    private var summaryContent: some View {
        if recording.transcript != nil {
            if recording.isSummarized {
                SummaryView(summary: recording.summary)
            } else {
                ProcessingStateView(message: "Generating summary...")
            }
        } else if recording.isTranscribed {
            EmptyStateView(
                icon: "exclamationmark.triangle.fill",
                title: "Transcription Failed",
                message: "No summary available without transcription",
                iconColor: .orange
            )
        } else {
            ProcessingStateView(message: "Processing transcription...")
        }
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if let transcript = recording.transcript {
            if let cleanedLines = transcript.cleanedLines, !cleanedLines.isEmpty {
                ScrollView {
                    TranscriptView(
                        lines: cleanedLines,
                        speakerCount: transcript.speakerCount
                    )
                    .padding(20)
                }
            } else if let cleanupError = transcript.cleanupError {
                EmptyStateView(
                    icon: "exclamationmark.triangle.fill",
                    title: "AI Cleanup Failed",
                    message: "JiteraBoost could not clean up the transcript: \(cleanupError)\n\nView the raw transcript instead.",
                    iconColor: .orange
                )
            } else {
                ScrollView {
                    TranscriptView(transcript: transcript)
                        .padding(20)
                }
            }
        } else if recording.isTranscribed {
            EmptyStateView(
                icon: "exclamationmark.triangle.fill",
                title: "Transcription Failed",
                message: "No speech detected in this recording",
                iconColor: .orange
            )
        } else {
            ProcessingStateView(message: "Processing transcription...")
        }
    }

    @ViewBuilder
    private var rawTranscriptContent: some View {
        if let transcript = recording.transcript {
            ScrollView {
                TranscriptView(transcript: transcript)
                    .padding(20)
            }
        } else if recording.isTranscribed {
            EmptyStateView(
                icon: "exclamationmark.triangle.fill",
                title: "Transcription Failed",
                message: "No speech detected in this recording",
                iconColor: .orange
            )
        } else {
            ProcessingStateView(message: "Processing transcription...")
        }
    }
}
