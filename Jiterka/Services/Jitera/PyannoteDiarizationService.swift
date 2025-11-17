//
//  PyannoteDiarizationService.swift
//  Jiterka
//
//  Service for speaker diarization using Python pyannote server
//

import Foundation

class PyannoteDiarizationService {
    static let shared = PyannoteDiarizationService()

    private let serverURL = "http://127.0.0.1:5555"

    private init() {}

    func isServerAvailable() async -> Bool {
        guard let url = URL(string: "\(serverURL)/health") else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    func diarize(audioPath: String, numSpeakers: Int? = nil) async throws -> PyannoteDiarizationResponse {
        guard let url = URL(string: "\(serverURL)/diarize") else {
            throw PyannoteDiarizationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes

        let requestBody: [String: Any?] = [
            "audio_path": audioPath,
            "num_speakers": numSpeakers
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PyannoteDiarizationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(PyannoteDiarizationResponse.self, from: data),
               let errorMessage = errorResponse.error {
                throw PyannoteDiarizationError.serverError(errorMessage)
            }
            throw PyannoteDiarizationError.httpError(httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(PyannoteDiarizationResponse.self, from: data)

        if let errorMessage = result.error {
            throw PyannoteDiarizationError.serverError(errorMessage)
        }

        return result
    }
}

enum PyannoteDiarizationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case serverNotAvailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid diarization server URL"
        case .invalidResponse:
            return "Invalid response from diarization server"
        case .httpError(let code):
            return "HTTP error \(code) from diarization server"
        case .serverError(let message):
            return "Diarization server error: \(message)"
        case .serverNotAvailable:
            return "Diarization server is not running on port 5555"
        }
    }
}
