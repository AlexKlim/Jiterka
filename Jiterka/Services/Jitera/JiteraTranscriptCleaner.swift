//
//  JiteraTranscriptCleaner.swift
//  Jiterka
//
//  Service for cleaning up transcriptions using JiteraBoost AI
//

import Foundation

@MainActor
class JiteraTranscriptCleaner: JiteraBoostClient {

    func cleanupTranscription(_ lines: [SpeakerLine], onProgress: ((String) -> Void)? = nil) async throws -> [SpeakerLine] {
        let formattedText = lines.map { "\($0.speakerId): \($0.text)" }.joined(separator: "\n")
        let maxSizePerRequest = 15000 // 15KB

        if formattedText.count > maxSizePerRequest {
            onProgress?("⚠️ Large transcript (\(formattedText.count) characters), processing in chunks")
            return try await cleanupInChunks(lines, onProgress: onProgress)
        }

        onProgress?("🤖 Cleaning up transcript...")
        return try await cleanupChunk(lines)
    }

    private func cleanupInChunks(_ lines: [SpeakerLine], onProgress: ((String) -> Void)?) async throws -> [SpeakerLine] {
        let linesPerChunk = 30
        var result: [SpeakerLine] = []

        let totalChunks = Int(ceil(Double(lines.count) / Double(linesPerChunk)))
        print("🤖 JiteraBoost: Processing \(lines.count) lines in \(totalChunks) chunks")
        onProgress?("🤖 Processing \(lines.count) lines in \(totalChunks) chunks")

        for chunkIndex in 0..<totalChunks {
            let start = chunkIndex * linesPerChunk
            let end = min(start + linesPerChunk, lines.count)
            let chunk = Array(lines[start..<end])

            print("📤 Processing chunk \(chunkIndex + 1)/\(totalChunks) (\(chunk.count) lines)")
            onProgress?("📤 Cleaning chunk \(chunkIndex + 1)/\(totalChunks)")

            let cleanedChunk = try await cleanupChunk(chunk)
            result.append(contentsOf: cleanedChunk)

            print("✅ Chunk \(chunkIndex + 1)/\(totalChunks) completed")
        }

        onProgress?("✅ Cleanup completed")
        return result
    }

    private func cleanupChunk(_ lines: [SpeakerLine]) async throws -> [SpeakerLine] {
        let systemPrompt = """
        You are a professional transcription editor. Your task is to remove filler words (such as 'uh', 'um', 'like', 'you know') and clean up the text while preserving the speaker's original meaning, tone, and natural speech patterns. Do not rephrase or change the core message - only remove unnecessary filler words.

        IMPORTANT: You must return EXACTLY the same number of lines as provided in the input. Each line must have a "speaker" and "text" field.
        """

        let formattedLines = lines.map { "\($0.speakerId): \($0.text)" }.joined(separator: "\n")

        let userPrompt = """
        Please clean up this audio transcription by removing filler words. Return exactly \(lines.count) lines in JSON format:

        \(formattedLines)

        Return the result as JSON with this structure:
        {
          "lines": [
            {"speaker": "SPEAKER_0", "text": "cleaned text here"},
            ...
          ]
        }
        """

        let response = try await makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        guard let firstChoice = response.choices?.first else {
            throw JiteraBoostError.noResult
        }

        let contentData = Data(firstChoice.message.content.utf8)

        do {
            let cleanedTranscript = try JSONDecoder().decode(CleanedTranscript.self, from: contentData)

            var result: [SpeakerLine] = []
            for (index, cleanedLine) in cleanedTranscript.lines.enumerated() {
                guard index < lines.count else {
                    print("⚠️ Warning: More cleaned lines (\(cleanedTranscript.lines.count)) than original lines (\(lines.count))")
                    break
                }

                let originalLine = lines[index]
                let speakerLine = SpeakerLine(
                    speakerId: cleanedLine.speaker,
                    text: cleanedLine.text,
                    startTime: originalLine.startTime,
                    endTime: originalLine.endTime
                )
                result.append(speakerLine)
            }

            return result
        } catch {
            print("❌ Failed to decode cleanup response:")
            print("Response content: \(firstChoice.message.content)")
            print("Decode error: \(error)")
            throw error
        }
    }
}
