//
//  TranscriptionError.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import Foundation

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case recognitionFailed(Error)
    case processingFailed
    case authorizationDenied
    case noTranscriptionAvailable
    case languageNotSupported(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .recognitionFailed(let error):
            return "Recognition failed: \(error.localizedDescription)"
        case .processingFailed:
            return "Failed to process transcription results"
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        case .noTranscriptionAvailable:
            return "No transcription available in analysis result"
        case .languageNotSupported(let locale):
            return "Language '\(locale)' is not supported for speech recognition"
        }
    }
}
