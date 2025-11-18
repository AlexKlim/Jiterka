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
        let aiResponse: String?
    }

    func syncRecording(
        name: String,
        date: Date,
        summary: String,
        cleanedTranscript: [SpeakerLine],
        onProgress: ((String) -> Void)? = nil
    ) async throws -> SyncResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let formattedDate = dateFormatter.string(from: date)

        let sanitizedName = sanitizeName(name)
        let folderName = "\(sanitizedName) (\(formattedDate))"

        // TODO: Split transcription into smaller chunks (50 lines per chunk)
        let linesPerChunk = 50
        let transcriptChunks = stride(from: 0, to: cleanedTranscript.count, by: linesPerChunk).map { start -> String in
            let end = min(start + linesPerChunk, cleanedTranscript.count)
            let chunkLines = cleanedTranscript[start..<end]
            return chunkLines.map { line in
                let timestamp = formatTimestamp(line.startTime)
                return "[\(timestamp)] \(line.speakerId): \(line.text)"
            }.joined(separator: "\n\n")
        }

        let totalSize = summary.count + transcriptChunks.joined(separator: "\n\n").count
        let maxSizePerRequest = 15000 // ~15KB per request

        onProgress?("📊 Content size: \(totalSize) characters, \(transcriptChunks.count) chunks")

        if totalSize > maxSizePerRequest {
            onProgress?("⚠️ Content is large, will send in multiple requests")
            return try await syncInMultipleRequests(
                folderName: folderName,
                summary: summary,
                transcriptChunks: transcriptChunks,
                onProgress: onProgress
            )
        }

        onProgress?("📤 Sending in single request")
        return try await syncInSingleRequest(
            folderName: folderName,
            summary: summary,
            transcriptChunks: transcriptChunks,
            onProgress: onProgress
        )
    }

    private func syncInMultipleRequests(
        folderName: String,
        summary: String,
        transcriptChunks: [String],
        onProgress: ((String) -> Void)?
    ) async throws -> SyncResult {
        onProgress?("📤 Request 1/\(transcriptChunks.count): Creating folder structure and initial content")
        var result = try await syncChunk(
            folderName: folderName,
            summary: summary,
            transcriptChunks: [transcriptChunks[0]],
            isFirstRequest: true,
            chunkNumber: 1,
            totalChunks: transcriptChunks.count,
            onProgress: onProgress
        )

        for (index, chunk) in transcriptChunks.dropFirst().enumerated() {
            let chunkNumber = index + 2
            onProgress?("📤 Request \(chunkNumber)/\(transcriptChunks.count): Appending chunk \(chunkNumber)")

            result = try await syncChunk(
                folderName: folderName,
                summary: nil,
                transcriptChunks: [chunk],
                isFirstRequest: false,
                chunkNumber: chunkNumber,
                totalChunks: transcriptChunks.count,
                onProgress: onProgress
            )
        }

        onProgress?("✅ All \(transcriptChunks.count) requests completed")
        return result
    }

    private func syncInSingleRequest(
        folderName: String,
        summary: String,
        transcriptChunks: [String],
        onProgress: ((String) -> Void)?
    ) async throws -> SyncResult {
        return try await syncChunk(
            folderName: folderName,
            summary: summary,
            transcriptChunks: transcriptChunks,
            isFirstRequest: true,
            chunkNumber: 1,
            totalChunks: 1,
            onProgress: onProgress
        )
    }

    private func syncChunk(
        folderName: String,
        summary: String?,
        transcriptChunks: [String],
        isFirstRequest: Bool,
        chunkNumber: Int,
        totalChunks: Int,
        onProgress: ((String) -> Void)?
    ) async throws -> SyncResult {

        let operation = isFirstRequest ? "CREATE/REPLACE" : "APPEND"

        let systemPrompt = """
        You are a document management assistant for Jitera. Your task is to create and update a structured folder hierarchy and save meeting documents.

        You have the ability to create folders and documents in the Jitera system, as well as update existing documents.

        CURRENT OPERATION: \(operation)

        \(isFirstRequest ? """
        This is REQUEST 1 of \(totalChunks) - INITIAL SETUP:
        1. Create a root folder called "Meeting Notes" (if it doesn't already exist)
        2. Inside "Meeting Notes", create a subfolder with the meeting name and date (if it doesn't already exist)
        3. In that subfolder, CREATE documents with initial content:
           - "Summary" - REPLACE any existing content with the new summary
           - "Transcription" - CREATE/REPLACE with the first chunk of transcription
        """ : """
        This is REQUEST \(chunkNumber) of \(totalChunks) - APPEND OPERATION:
        1. The folder structure already exists from the first request
        2. APPEND content to the existing "Transcription" document
        3. DO NOT replace existing content - ADD the new content to the END of the file
        4. DO NOT modify the Summary document
        """)

        IMPORTANT:
        - File name for transcription: "Transcription"
        - \(isFirstRequest ? "For the first request: CREATE or REPLACE content" : "For subsequent requests: APPEND content to the existing Transcription file")

        Ensure all operations complete successfully and return the paths to confirm.
        """

        let transcriptionContent = transcriptChunks.joined(separator: "\n\n")

        let userPrompt: String
        if isFirstRequest {
            userPrompt = """
            REQUEST 1/\(totalChunks): CREATE folder structure and initial documents

            **Folder Structure:**
            - Meeting Notes/
              - \(folderName)/
                - Summary (CREATE or REPLACE content)
                - Transcription (CREATE or REPLACE content with chunk 1)

            \(summary != nil ? """
            **Summary Content (to be written/replaced):**
            \(summary!)

            """ : "")
            **Transcription Content (to be written/replaced):**
            \(transcriptionContent)

            Please CREATE the folder structure and documents with the content above, and confirm with the full paths and project name.
            """
        } else {
            userPrompt = """
            REQUEST \(chunkNumber)/\(totalChunks): APPEND content to existing Transcription document

            **Target Folder:**
            - Meeting Notes/\(folderName)/

            **Content to APPEND to Transcription file:**
            \(transcriptionContent)

            Please APPEND the content above to the END of the existing "Transcription" document.
            DO NOT replace existing content - ADD to the end.
            DO NOT modify the Summary document.

            Please confirm with the full paths and project name.
            """
        }

        onProgress?("🤖 Sending request \(chunkNumber)/\(totalChunks) to JiteraBoost AI...")

        let response = try await makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        guard let firstChoice = response.choices?.first else {
            throw JiteraBoostError.noResult
        }

        let aiResponseText = firstChoice.message.content
        onProgress?("✅ Request \(chunkNumber)/\(totalChunks) completed")

        let result = SyncResult(
            success: true,
            folderPath: "Meeting Notes/\(folderName)",
            summaryFilePath: "Meeting Notes/\(folderName)/Summary",
            transcriptionFilePath: "Meeting Notes/\(folderName)/Transcription",
            message: "Request \(chunkNumber)/\(totalChunks) completed",
            aiResponse: aiResponseText
        )

        return result
    }

    private func formatTimestamp(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func sanitizeName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*\\/")
        return name.components(separatedBy: invalidCharacters).joined(separator: "-")
    }
}
