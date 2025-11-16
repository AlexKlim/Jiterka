//
//  JiterBoostService.swift
//  Jiterka
//
//  AI service for enhancing transcriptions
//

import Foundation

@MainActor
class JiterBoostService {
    private let apiURL = URL(string: "https://ai.jitera.app/v1/chat/completions")!
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Codable {
        let type: String
        let jsonSchema: JSONSchema

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }
    }

    struct JSONSchema: Codable {
        let name: String
        let strict: Bool
        let schema: Schema
    }

    struct Schema: Codable {
        let type: String
        let properties: Properties
        let required: [String]
        let additionalProperties: Bool

        enum CodingKeys: String, CodingKey {
            case type, properties, required
            case additionalProperties = "additionalProperties"
        }
    }

    struct Properties: Codable {
        let lines: LinesProperty
    }

    struct LinesProperty: Codable {
        let type: String
        let items: LineItem
    }

    struct LineItem: Codable {
        let type: String
        let properties: LineProperties
        let required: [String]
        let additionalProperties: Bool

        enum CodingKeys: String, CodingKey {
            case type, properties, required
            case additionalProperties = "additionalProperties"
        }
    }

    struct LineProperties: Codable {
        let speaker: StringType
        let text: StringType
    }

    struct StringType: Codable {
        let type: String
    }

    struct JiterBoostRequest: Codable {
        let model: String
        let messages: [Message]
        let responseFormat: ResponseFormat

        enum CodingKeys: String, CodingKey {
            case model, messages
            case responseFormat = "response_format"
        }
    }

    struct JiterBoostResponse: Codable {
        let choices: [Choice]?
        let error: String?

        struct Choice: Codable {
            let message: Message
        }
    }

    struct CleanedTranscript: Codable {
        let lines: [CleanedLine]
    }

    struct CleanedLine: Codable {
        let speaker: String
        let text: String
    }
    
    func cleanupTranscription(_ lines: [SpeakerLine]) async throws -> [SpeakerLine] {
        let systemPrompt = """
        You are a professional transcription editor. Your task is to remove filler words (such as 'uh', 'um', 'like', 'you know') and clean up the text while preserving the speaker's original meaning, tone, and natural speech patterns. Do not rephrase or change the core message - only remove unnecessary filler words.
        """

        // Format lines as text for the prompt
        let formattedLines = lines.map { "\($0.speakerId): \($0.text)" }.joined(separator: "\n")

        let userPrompt = """
        Please clean up this audio transcription by removing filler words:

        \(formattedLines)
        """

        let responseFormat = ResponseFormat(
            type: "json_schema",
            jsonSchema: JSONSchema(
                name: "cleaned_transcript",
                strict: true,
                schema: Schema(
                    type: "object",
                    properties: Properties(
                        lines: LinesProperty(
                            type: "array",
                            items: LineItem(
                                type: "object",
                                properties: LineProperties(
                                    speaker: StringType(type: "string"),
                                    text: StringType(type: "string")
                                ),
                                required: ["speaker", "text"],
                                additionalProperties: false
                            )
                        )
                    ),
                    required: ["lines"],
                    additionalProperties: false
                )
            )
        )

        let requestBody = JiterBoostRequest(
            model: "jitera/document_agent",
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: userPrompt)
            ],
            responseFormat: responseFormat
        )

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        print("🤖 JiterBoost: Cleaning up \(lines.count) lines...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JiterBoostError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ JiterBoost API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw JiterBoostError.apiError(httpResponse.statusCode, errorMessage)
        }

        let boostResponse = try JSONDecoder().decode(JiterBoostResponse.self, from: data)

        if let error = boostResponse.error {
            print("❌ JiterBoost returned error: \(error)")
            throw JiterBoostError.apiError(httpResponse.statusCode, error)
        }

        guard let choices = boostResponse.choices, let firstChoice = choices.first else {
            throw JiterBoostError.noResult
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

        print("✅ JiterBoost: Cleaned \(result.count) lines successfully")
        return result
    }
}

enum JiterBoostError: LocalizedError {
    case invalidResponse
    case apiError(Int, String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from JiterBoost API"
        case .apiError(let code, let message):
            return "JiterBoost API error (\(code)): \(message)"
        case .noResult:
            return "No result returned from JiterBoost API"
        }
    }
}
