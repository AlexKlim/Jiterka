//
//  JiteraTranscriptCleaner.swift
//  Jiterka
//
//  Service for cleaning up transcriptions using JiteraBoost AI
//

import Foundation

@MainActor
class JiteraTranscriptCleaner: JiteraBoostClient {

    func cleanupTranscription(_ lines: [SpeakerLine]) async throws -> [SpeakerLine] {
        let systemPrompt = """
        You are a professional transcription editor. Your task is to remove filler words (such as 'uh', 'um', 'like', 'you know') and clean up the text while preserving the speaker's original meaning, tone, and natural speech patterns. Do not rephrase or change the core message - only remove unnecessary filler words.
        """

        let formattedLines = lines.map { "\($0.speakerId): \($0.text)" }.joined(separator: "\n")

        let userPrompt = """
        Please clean up this audio transcription by removing filler words:

        \(formattedLines)
        """

        let schema = createTranscriptCleanupSchema()

        print("🤖 JiteraBoost: Cleaning up \(lines.count) lines...")

        let response = try await makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            responseSchema: schema
        )

        guard let firstChoice = response.choices?.first else {
            throw JiteraBoostError.noResult
        }

        let contentData = Data(firstChoice.message.content.utf8)
        let cleanedTranscript = try JSONDecoder().decode(CleanedTranscript.self, from: contentData)

        var result: [SpeakerLine] = []
        for (index, cleanedLine) in cleanedTranscript.lines.enumerated() {
            guard index < lines.count else {
                print("⚠️ Warning: More cleaned lines than original lines")
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

        print("✅ JiteraBoost: Cleaned \(result.count) lines successfully")
        return result
    }

    private func createTranscriptCleanupSchema() -> [String: Any] {
        return [
            "type": "json_schema",
            "json_schema": [
                "name": "cleaned_transcript",
                "strict": true,
                "schema": [
                    "type": "object",
                    "properties": [
                        "lines": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "speaker": ["type": "string"],
                                    "text": ["type": "string"]
                                ],
                                "required": ["speaker", "text"],
                                "additionalProperties": false
                            ]
                        ]
                    ],
                    "required": ["lines"],
                    "additionalProperties": false
                ]
            ]
        ]
    }
}
