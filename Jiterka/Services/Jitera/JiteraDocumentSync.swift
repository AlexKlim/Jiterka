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

        let transcriptionText = cleanedTranscript.map { line in
            let timestamp = formatTimestamp(line.startTime)
            return "[\(timestamp)] \(line.speakerId): \(line.text)"
        }.joined(separator: "\n\n")

        let systemPrompt = """
        You are a document management assistant for Jitera. Your task is to create and update a structured folder hierarchy and save meeting documents.

        You have the ability to create folders and documents in the Jitera system, as well as update existing documents.

        Please perform the following actions:
        1. Create a root folder called "Meeting Notes" (if it doesn't already exist)
        2. Inside "Meeting Notes", create a subfolder with the meeting name and date (if it doesn't already exist)
        3. In that subfolder, create or update two documents:
           - "Summary" - containing the meeting summary in markdown format
           - "Transcription" - containing the full cleaned transcription with timestamps

        IMPORTANT: If a document already exists (Summary or Transcription), UPDATE it by completely replacing its content with the new content. DO NOT create duplicate files. Always use the same file names.

        Ensure all folders and files are created/updated successfully and return the paths to confirm.
        """

        let userPrompt = """
        Please create or update the following folder structure and documents:

        **Folder Structure:**
        - Meeting Notes/
          - \(folderName)/
            - Summary (create new if doesn't exist, otherwise UPDATE/REPLACE content)
            - Transcription (create new if doesn't exist, otherwise UPDATE/REPLACE content)

        **Summary Content (to be written/updated):**
        \(summary)

        **Transcription Content (to be written/updated):**
        \(transcriptionText)

        If the folder "Meeting Notes/\(folderName)/" already exists with Summary and/or Transcription files, UPDATE those files by replacing their entire content with the new content provided above. Do not create duplicate files.

        Please process this operation and confirm with the full paths.
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
