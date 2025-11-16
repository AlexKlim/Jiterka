//
//  JiteraDocumentSync.swift
//  Jiterka
//
//  Syncs meeting recordings to Jitera as documents
//

import Foundation

@MainActor
class JiteraDocumentSync: JiteraBoostClient {

    struct SyncRequest: Codable {
        let meetingName: String
        let meetingDate: String
        let summary: String
        let transcription: String
    }

    struct SyncResult: Codable {
        let success: Bool
        let folderPath: String
        let summaryFilePath: String
        let transcriptionFilePath: String
        let message: String
    }

    func syncRecording(
        name: String,
        date: Date,
        summary: String,
        cleanedTranscript: [SpeakerLine]
    ) async throws -> SyncResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let formattedDate = dateFormatter.string(from: date)

        let folderName = "\(name) (\(formattedDate))"

        // Format cleaned transcript
        let transcriptionText = cleanedTranscript.map { line in
            let timestamp = formatTimestamp(line.startTime)
            return "[\(timestamp)] \(line.speakerId): \(line.text)"
        }.joined(separator: "\n\n")

        let systemPrompt = """
        You are a document management assistant for Jitera. Your task is to create a structured folder hierarchy and save meeting documents.

        You have the ability to create folders and documents in the Jitera system.

        Please perform the following actions:
        1. Create a root folder called "Meeting Notes" (if it doesn't already exist)
        2. Inside "Meeting Notes", create a subfolder with the meeting name and date
        3. In that subfolder, create two documents:
           - "Summary" - containing the meeting summary in markdown format
           - "Transcription" - containing the full cleaned transcription with timestamps

        Ensure all folders and files are created successfully and return the paths to confirm.
        """

        let userPrompt = """
        Please create the following folder structure and documents:

        **Folder Structure:**
        - Meeting Notes/
          - \(folderName)/
            - Summary
            - Transcription

        **Summary Content:**
        \(summary)

        **Transcription Content:**
        \(transcriptionText)

        Please create these folders and documents, then confirm the operation with the full paths.
        """

        let responseSchema: [String: Any] = [
            "type": "json_schema",
            "json_schema": [
                "name": "sync_result",
                "strict": true,
                "schema": [
                    "type": "object",
                    "properties": [
                        "success": [
                            "type": "boolean",
                            "description": "Whether the sync operation was successful"
                        ],
                        "folderPath": [
                            "type": "string",
                            "description": "The full path to the created meeting folder"
                        ],
                        "summaryFilePath": [
                            "type": "string",
                            "description": "The full path to the Summary document"
                        ],
                        "transcriptionFilePath": [
                            "type": "string",
                            "description": "The full path to the Transcription document"
                        ],
                        "message": [
                            "type": "string",
                            "description": "A message describing the result of the operation"
                        ]
                    ],
                    "required": ["success", "folderPath", "summaryFilePath", "transcriptionFilePath", "message"],
                    "additionalProperties": false
                ]
            ]
        ]

        let response = try await makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            responseSchema: responseSchema
        )

        guard let firstChoice = response.choices?.first else {
            throw JiteraBoostError.noResult
        }

        // Parse the JSON content
        let contentData = Data(firstChoice.message.content.utf8)
        let result = try JSONDecoder().decode(SyncResult.self, from: contentData)

        return result
    }

    private func formatTimestamp(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
