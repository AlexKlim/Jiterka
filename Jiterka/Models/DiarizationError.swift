//
//  DiarizationError.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import Foundation

enum DiarizationError: LocalizedError {
    case managerNotInitialized
    case modelPreparationFailed(Error)
    case processingFailed(Error)
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .managerNotInitialized:
            return "Diarization manager not initialized"
        case .modelPreparationFailed(let error):
            return "Failed to prepare models: \(error.localizedDescription)"
        case .processingFailed(let error):
            return "Diarization failed: \(error.localizedDescription)"
        case .audioConversionFailed:
            return "Failed to convert audio format"
        }
    }
}
