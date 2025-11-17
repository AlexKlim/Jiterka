//
//  JiteraModels.swift
//  Jiterka
//
//  Models for JiteraBoost AI service
//

import Foundation

// MARK: - Common Models

struct JiteraMessage: Codable {
    let role: String
    let content: String
}

struct JiteraResponse: Codable {
    let choices: [Choice]?
    let error: String?

    struct Choice: Codable {
        let message: JiteraMessage
    }
}

enum JiteraBoostError: LocalizedError {
    case invalidResponse
    case apiError(Int, String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from JiteraBoost API"
        case .apiError(let code, let message):
            return "JiteraBoost API error (\(code)): \(message)"
        case .noResult:
            return "No result returned from JiteraBoost API"
        }
    }
}

// MARK: - Transcript Models

struct CleanedTranscript: Codable {
    let lines: [CleanedLine]
}

struct CleanedLine: Codable {
    let speaker: String
    let text: String
}

// MARK: - Summary Models

struct MeetingSummary: Codable {
    let overview: String
    let participants: [String]
    let keyPoints: [String]
    let actionItems: [ActionItem]
    let decisions: [String]
    let topics: [String]
    let nextSteps: [String]
}

struct ActionItem: Codable {
    let speaker: String?
    let task: String
    let priority: String?
}

// MARK: - Pyannote Diarization Models

struct PyannoteDiarizationResponse: Codable {
    let segments: [PyannoteSegment]
    let numSpeakers: Int
    let error: String?

    enum CodingKeys: String, CodingKey {
        case segments
        case numSpeakers = "num_speakers"
        case error
    }
}

struct PyannoteSegment: Codable {
    let speaker: String
    let start: Double
    let end: Double
}
