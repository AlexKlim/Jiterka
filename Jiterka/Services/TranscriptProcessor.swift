//
//  TranscriptProcessor.swift
//  Jiterka
//
//  Combines transcription and diarization results
//

import Foundation
import Combine

@MainActor
class TranscriptProcessor: ObservableObject {
    private let transcriptionManager = TranscriptionManager()
    private let diarizationManager = DiarizationManager()
    private var transcriptCleaner: JiteraTranscriptCleaner?
    private var summarizer: JiteraSummarizer?
    private var documentSync: JiteraDocumentSync?

    init() {
        if JiteraBoostConfig.isConfigured {
            transcriptCleaner = JiteraTranscriptCleaner(apiKey: JiteraBoostConfig.apiKey)
            summarizer = JiteraSummarizer(apiKey: JiteraBoostConfig.apiKey)
            documentSync = JiteraDocumentSync(apiKey: JiteraBoostConfig.apiKey)
            print("✅ JiteraBoost services initialized")
        } else {
            print("⚠️ JiteraBoost API key not configured - AI features will be skipped")
        }
    }

    @available(macOS 26.0, *)
    func processAudio(url: URL) async throws -> ProcessedTranscript {
        let authorized = await transcriptionManager.requestAuthorization()
        guard authorized else {
            throw TranscriptionError.authorizationDenied
        }

        try await diarizationManager.prepareModels()

        async let transcriptionTask = transcriptionManager.transcribe(audioURL: url)
        async let diarizationTask = diarizationManager.diarize(audioURL: url)

        let (transcription, diarization) = try await (transcriptionTask, diarizationTask)

        let mergedTranscript = mergeResults(
            transcription: transcription,
            diarization: diarization
        )

        if let cleaner = transcriptCleaner {
            do {
                let cleanedLines = try await cleaner.cleanupTranscription(mergedTranscript.lines)
                let cleanedFullText = cleanedLines.map { $0.text }.joined(separator: " ")

                return ProcessedTranscript(
                    lines: mergedTranscript.lines,
                    fullText: mergedTranscript.fullText,
                    speakerCount: mergedTranscript.speakerCount,
                    cleanedLines: cleanedLines,
                    cleanedFullText: cleanedFullText
                )
            } catch {
                return ProcessedTranscript(
                    lines: mergedTranscript.lines,
                    fullText: mergedTranscript.fullText,
                    speakerCount: mergedTranscript.speakerCount,
                    cleanupError: error.localizedDescription
                )
            }
        }

        return mergedTranscript
    }

    func generateSummary(for transcript: ProcessedTranscript) async throws -> String {
        guard let summarizer = summarizer else {
            throw TranscriptionError.processingFailed
        }

        do {
            let summary = try await summarizer.generateSummary(from: transcript)
            let markdown = summarizer.formatSummaryAsMarkdown(summary)
            return markdown
        } catch {
            print("❌ Failed to generate summary: \(error.localizedDescription)")
            throw error
        }
    }

    func syncToJitera(
        name: String,
        date: Date,
        summary: String,
        transcript: ProcessedTranscript,
        onProgress: ((String) -> Void)? = nil
    ) async throws -> JiteraDocumentSync.SyncResult {
        guard let documentSync = documentSync else {
            throw TranscriptionError.processingFailed
        }

        let transcriptToSync = transcript.cleanedLines ?? transcript.lines

        do {
            let result = try await documentSync.syncRecording(
                name: name,
                date: date,
                summary: summary,
                cleanedTranscript: transcriptToSync,
                onProgress: onProgress
            )
            return result
        } catch {
            throw error
        }
    }
    
    private func mergeResults(
        transcription: TranscriptionResult,
        diarization: DiarizationResult
    ) -> ProcessedTranscript {
        var speakerLines: [SpeakerLine] = []
        var speakerIdMap: [String: Int] = [:]
        var nextSpeakerNumber = 1

        print("🔍 Merging transcription (\(transcription.segments.count) segments) with diarization (\(diarization.segments.count) speaker segments)")
        print("🔍 Speaker count from diarization: \(diarization.speakerCount)")

        for (index, segment) in transcription.segments.enumerated() {
            let segmentStart = segment.startTime
            let segmentEnd = segment.startTime + segment.duration

            let overlappingSpeakers = diarization.segments.filter { speakerSegment in
                segmentStart < speakerSegment.endTime && segmentEnd > speakerSegment.startTime
            }

            print("📝 Transcription segment [\(index)]: '\(segment.text.prefix(30))...' Time: \(segmentStart)-\(segmentEnd), Found \(overlappingSpeakers.count) overlapping speakers")

            var speakerId: String
            if let bestSpeaker = findBestMatchingSpeaker(overlappingSpeakers, segmentStart: segmentStart, segmentEnd: segmentEnd) {
                if let existingNumber = speakerIdMap[bestSpeaker.speakerId] {
                    speakerId = "SPEAKER_\(existingNumber)"
                } else {
                    speakerIdMap[bestSpeaker.speakerId] = nextSpeakerNumber
                    speakerId = "SPEAKER_\(nextSpeakerNumber)"
                    nextSpeakerNumber += 1
                }
                print("  ✅ Matched to: \(speakerId) (original: \(bestSpeaker.speakerId))")
            } else {
                speakerId = "SPEAKER_0"
                print("  ⚠️ No speaker match found - marked as Unknown Speaker")
            }

            if let lastLine = speakerLines.last, lastLine.speakerId == speakerId {
                speakerLines[speakerLines.count - 1].text += " " + segment.text
                speakerLines[speakerLines.count - 1].endTime = segment.endTime
            } else {
                let line = SpeakerLine(
                    speakerId: speakerId,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
                speakerLines.append(line)
            }
        }

        return ProcessedTranscript(
            lines: speakerLines,
            fullText: transcription.fullText,
            speakerCount: max(nextSpeakerNumber - 1, diarization.speakerCount)
        )
    }

    private func findBestMatchingSpeaker(_ speakers: [SpeakerSegment], segmentStart: TimeInterval, segmentEnd: TimeInterval) -> SpeakerSegment? {
        guard !speakers.isEmpty else { return nil }

        if speakers.count == 1 {
            return speakers.first
        }

        var bestSpeaker: SpeakerSegment?
        var maxOverlap: TimeInterval = 0

        for speaker in speakers {
            let overlapStart = max(segmentStart, speaker.startTime)
            let overlapEnd = min(segmentEnd, speaker.endTime)
            let overlap = overlapEnd - overlapStart

            if overlap > maxOverlap {
                maxOverlap = overlap
                bestSpeaker = speaker
            }
        }

        return bestSpeaker
    }

    func exportAsText(_ transcript: ProcessedTranscript) -> String {
        var output = ""

        for line in transcript.lines {
            let timestamp = formatTimestamp(line.startTime)
            let speakerName = formatSpeakerName(line.speakerId)
            output += "[\(timestamp)] \(speakerName): \(line.text)\n\n"
        }

        return output
    }

    private func formatSpeakerName(_ speakerId: String) -> String {
        if speakerId.starts(with: "SPEAKER_") {
            let number = speakerId.replacingOccurrences(of: "SPEAKER_", with: "")
            if let num = Int(number) {
                return "Speaker \(num + 1)"
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
