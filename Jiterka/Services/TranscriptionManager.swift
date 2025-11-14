//
//  TranscriptionManager.swift
//  Jiterka
//
//  Apple Speech Framework for transcription
//

import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
class TranscriptionManager: ObservableObject {
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    @available(macOS 26.0, *)
    func transcribe(audioURL: URL, language: String? = nil) async throws -> TranscriptionResult {

        // TODO: uses device language. Need to adjust to use AI(?) recognize the main language
        let locale = if let language = language {
            Locale(identifier: language)
        } else {
            Locale.current
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioURL)

        let _ = try await analyzer.analyzeSequence(from: audioFile)
        try await analyzer.finalizeAndFinishThroughEndOfInput()

        var fullText = ""
        var segments: [TranscriptionSegment] = []

        for try await result in transcriber.results {
            if result.isFinal {
                let text = String(result.text.characters)
                fullText += text + " "

                let (timestamp, duration) = extractTimestamp(from: result)

                let segment = TranscriptionSegment(
                    text: text,
                    startTime: timestamp,
                    duration: duration,
                    confidence: 1.0
                )
                segments.append(segment)
            }
        }

        return TranscriptionResult(
            fullText: fullText.trimmingCharacters(in: .whitespaces),
            segments: segments
        )
    }

    @available(macOS 26.0, *)
    private func extractTimestamp(from response: SpeechTranscriber.Result) -> (start: TimeInterval, duration: TimeInterval) {
        var minStart: TimeInterval?
        var maxEnd: TimeInterval?

        response.text.runs.forEach { run in
            if let timeRange = run.audioTimeRange {
                let start = CMTimeGetSeconds(timeRange.start)
                let end = start + CMTimeGetSeconds(timeRange.duration)

                if minStart == nil || start < minStart! {
                    minStart = start
                }
                if maxEnd == nil || end > maxEnd! {
                    maxEnd = end
                }
            }
        }

        if let minStart = minStart, let maxEnd = maxEnd {
            return (minStart, maxEnd - minStart)
        }

        return (0.0, 0.0)
    }
}
