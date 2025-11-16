//
//  JiteraSummarizer.swift
//  Jiterka
//
//  Service for generating meeting summaries using JiteraBoost AI
//

import Foundation

@MainActor
class JiteraSummarizer: JiteraBoostClient {

    func generateSummary(from transcript: ProcessedTranscript) async throws -> MeetingSummary {
        let systemPrompt = """
        You are a professional meeting summarizer. Analyze the meeting transcript and create a comprehensive summary with:
        - Brief overview (2-3 sentences)
        - List of participants
        - Key points discussed
        - Action items with assignees if mentioned
        - Decisions made
        - Topics covered
        - Next steps

        Be concise but informative. Extract all important information accurately.
        """

        let transcriptText: String
        if let cleanedLines = transcript.cleanedLines {
            transcriptText = cleanedLines.map { "\($0.speakerId): \($0.text)" }.joined(separator: "\n")
        } else {
            transcriptText = transcript.lines.map { "\($0.speakerId): \($0.text)" }.joined(separator: "\n")
        }

        let userPrompt = """
        Please analyze this meeting transcript and create a comprehensive summary:

        \(transcriptText)
        """

        let schema = createSummarySchema()

        print("🤖 JiteraBoost: Generating meeting summary...")

        let response = try await makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            responseSchema: schema
        )

        guard let firstChoice = response.choices?.first else {
            throw JiteraBoostError.noResult
        }

        // Parse the JSON content
        let contentData = Data(firstChoice.message.content.utf8)
        let summary = try JSONDecoder().decode(MeetingSummary.self, from: contentData)

        print("✅ JiteraBoost: Summary generated successfully")
        return summary
    }

    func formatSummaryAsMarkdown(_ summary: MeetingSummary) -> String {
        var markdown = "# Meeting Summary\n\n"

        markdown += "## Overview\n\n"
        markdown += summary.overview + "\n\n"

        if !summary.participants.isEmpty {
            markdown += "## Participants\n\n"
            for participant in summary.participants {
                markdown += "- \(participant)\n"
            }
            markdown += "\n"
        }

        if !summary.keyPoints.isEmpty {
            markdown += "## Key Points\n\n"
            for point in summary.keyPoints {
                markdown += "- \(point)\n"
            }
            markdown += "\n"
        }

        if !summary.actionItems.isEmpty {
            markdown += "## Action Items\n\n"
            for item in summary.actionItems {
                var line = "- [ ] "
                if let speaker = item.speaker {
                    line += "**\(speaker)**: "
                }
                line += item.task
                if let priority = item.priority {
                    line += " _[\(priority)]_"
                }
                markdown += line + "\n"
            }
            markdown += "\n"
        }

        if !summary.decisions.isEmpty {
            markdown += "## Decisions Made\n\n"
            for decision in summary.decisions {
                markdown += "- \(decision)\n"
            }
            markdown += "\n"
        }

        if !summary.topics.isEmpty {
            markdown += "## Topics Discussed\n\n"
            for topic in summary.topics {
                markdown += "- \(topic)\n"
            }
            markdown += "\n"
        }

        if !summary.nextSteps.isEmpty {
            markdown += "## Next Steps\n\n"
            for step in summary.nextSteps {
                markdown += "- \(step)\n"
            }
            markdown += "\n"
        }

        return markdown
    }

    private func createSummarySchema() -> [String: Any] {
        return [
            "type": "json_schema",
            "json_schema": [
                "name": "meeting_summary",
                "strict": true,
                "schema": [
                    "type": "object",
                    "properties": [
                        "overview": ["type": "string"],
                        "participants": [
                            "type": "array",
                            "items": ["type": "string"]
                        ],
                        "keyPoints": [
                            "type": "array",
                            "items": ["type": "string"]
                        ],
                        "actionItems": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "speaker": [
                                        "anyOf": [
                                            ["type": "string"],
                                            ["type": "null"]
                                        ]
                                    ],
                                    "task": ["type": "string"],
                                    "priority": [
                                        "anyOf": [
                                            ["type": "string"],
                                            ["type": "null"]
                                        ]
                                    ]
                                ],
                                "required": ["speaker", "task", "priority"],
                                "additionalProperties": false
                            ]
                        ],
                        "decisions": [
                            "type": "array",
                            "items": ["type": "string"]
                        ],
                        "topics": [
                            "type": "array",
                            "items": ["type": "string"]
                        ],
                        "nextSteps": [
                            "type": "array",
                            "items": ["type": "string"]
                        ]
                    ],
                    "required": ["overview", "participants", "keyPoints", "actionItems", "decisions", "topics", "nextSteps"],
                    "additionalProperties": false
                ]
            ]
        ]
    }
}
