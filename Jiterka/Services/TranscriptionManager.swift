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
        // or add switcher - language selection
        let locale: Locale
        if let language = language {
            let candidateLocale = Locale(identifier: language)
            let bcp47 = candidateLocale.identifier(.bcp47)
            locale = Locale(components: Locale.Components(identifier: bcp47))
        } else {
            locale = Locale.current
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        try await ensureModel(transcriber: transcriber, locale: locale)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioURL)

        var fullText = ""
        var segments: [TranscriptionSegment] = []

        let resultsTask = Task {
            var resultCount = 0
            for try await result in transcriber.results {
                resultCount += 1

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
                } else {
                    let text = String(result.text.characters)
                }
            }
        }

        let _ = try await analyzer.analyzeSequence(from: audioFile)
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await resultsTask.value

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

    // MARK: - Language Model Management

    @available(macOS 26.0, *)
    private func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        let supportedLocales = await SpeechTranscriber.supportedLocales
        let localeBcp47 = locale.identifier(.bcp47)
        let isSupported = supportedLocales.map { $0.identifier(.bcp47) }.contains(localeBcp47)

        guard isSupported else {
            print("⚠️ Locale \(localeBcp47) is not supported")
            print("💡 All supported locales:")
            for locale in supportedLocales {
                print("   - \(locale.identifier(.bcp47))")
            }
            throw TranscriptionError.languageNotSupported(locale.identifier)
        }

        if await isInstalled(locale: locale) {
            print("✅ Language model for \(localeBcp47) is already installed")
            return
        }

        try await downloadIfNeeded(for: transcriber)
    }

    @available(macOS 26.0, *)
    private func isInstalled(locale: Locale) async -> Bool {
        let installed = await SpeechTranscriber.installedLocales
        let localeBcp47 = locale.identifier(.bcp47)
        return installed.map { $0.identifier(.bcp47) }.contains(localeBcp47)
    }

    @available(macOS 26.0, *)
    private func downloadIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await downloader.downloadAndInstall()
        }
    }
}
