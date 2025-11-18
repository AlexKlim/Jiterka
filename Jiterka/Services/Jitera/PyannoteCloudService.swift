//
//  PyannoteCloudService.swift
//  Jiterka
//
//  Service for speaker diarization using pyannote.ai cloud API
//  Docs: https://docs.pyannote.ai/
//

import Foundation

class PyannoteCloudService {
    static let shared = PyannoteCloudService()

    private let baseURL = "https://api.pyannote.ai/v1"
    private var apiKey: String?

    private init() {
        // Super DEV key. I don't worry, can be in repo
        self.apiKey = "sk_83a1f6b04ce8418d92cad02bfc29763f" // ProcessInfo.processInfo.environment["PYANNOTE_API_KEY"]
    }

    func setAPIKey(_ key: String) {
        self.apiKey = key
    }

    var isConfigured: Bool {
        return apiKey != nil && !(apiKey?.isEmpty ?? true)
    }

    func diarize(audioURL: URL) async throws -> PyannoteDiarizationResponse {
        guard isConfigured, let apiKey = apiKey else {
            throw PyannoteCloudError.apiKeyNotConfigured
        }
        
        let mediaKey = try await uploadAudioFile(audioURL: audioURL, apiKey: apiKey)
        let jobId = try await startDiarization(mediaKey: mediaKey, apiKey: apiKey)
        let result = try await pollForResults(jobId: jobId, apiKey: apiKey)

        return result
    }

    private func uploadAudioFile(audioURL: URL, apiKey: String) async throws -> String {
        let mediaKey = "media://jiterka-\(UUID().uuidString)"

        guard let requestURL = URL(string: "\(baseURL)/media/input") else {
            throw PyannoteCloudError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ["url": mediaKey]
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PyannoteCloudError.uploadFailed("Invalid response from server")
        }

        guard (200...201).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PyannoteCloudError.uploadFailed("Status \(httpResponse.statusCode): \(errorMessage)")
        }

        let uploadResponse = try JSONDecoder().decode(UploadURLResponse.self, from: data)

        guard let uploadURL = URL(string: uploadResponse.url) else {
            throw PyannoteCloudError.invalidURL
        }

        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = try Data(contentsOf: audioURL)

        let (_, uploadHTTPResponse) = try await URLSession.shared.data(for: uploadRequest)

        guard let uploadHTTP = uploadHTTPResponse as? HTTPURLResponse else {
            throw PyannoteCloudError.uploadFailed("Invalid upload response")
        }

        guard uploadHTTP.statusCode == 200 else {
            print("❌ File upload to S3 failed: Status \(uploadHTTP.statusCode)")
            throw PyannoteCloudError.uploadFailed("S3 upload failed with status \(uploadHTTP.statusCode)")
        }

        return mediaKey
    }

    private func startDiarization(mediaKey: String, apiKey: String) async throws -> String {
        guard let requestURL = URL(string: "\(baseURL)/diarize") else {
            throw PyannoteCloudError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ["url": mediaKey]
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PyannoteCloudError.diarizationFailed("Invalid response")
        }

        guard (200...201).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Start diarization failed: Status \(httpResponse.statusCode)")
            print("   Response: \(errorMessage)")
            throw PyannoteCloudError.diarizationFailed("Status \(httpResponse.statusCode): \(errorMessage)")
        }

        let jobResponse = try JSONDecoder().decode(JobResponse.self, from: data)
        return jobResponse.jobId
    }

    private func pollForResults(jobId: String, apiKey: String, maxAttempts: Int = 60) async throws -> PyannoteDiarizationResponse {
        guard let requestURL = URL(string: "\(baseURL)/jobs/\(jobId)") else {
            throw PyannoteCloudError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        for attempt in 0..<maxAttempts {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PyannoteCloudError.pollingFailed("Invalid polling response")
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Polling failed: Status \(httpResponse.statusCode)")
                print("   Response: \(errorMessage)")
                throw PyannoteCloudError.pollingFailed("Status \(httpResponse.statusCode): \(errorMessage)")
            }

            if let rawResponse = String(data: data, encoding: .utf8) {
                print("📝 Raw response: \(rawResponse)")
            }

            let jobStatus: JobStatusResponse
            do {
                jobStatus = try JSONDecoder().decode(JobStatusResponse.self, from: data)
            } catch {
                print("❌ JSON decode error: \(error)")
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("   Raw data: \(rawResponse)")
                }
                throw error
            }

            switch jobStatus.status {
            case "succeeded":
                guard let output = jobStatus.output else {
                    throw PyannoteCloudError.noOutput
                }
                let segments = output.diarization
                let speakers = Set(segments.map { $0.speaker })

                return PyannoteDiarizationResponse(
                    segments: segments,
                    numSpeakers: speakers.count,
                    error: output.error ?? output.warning
                )

            case "failed":
                throw PyannoteCloudError.diarizationFailed("Job failed: \(jobStatus.error ?? "unknown error")")

            case "canceled":
                throw PyannoteCloudError.diarizationFailed("Job was canceled")

            case "created", "processing", "running":
                if attempt < maxAttempts - 1 {
                    print("  Status: \(jobStatus.status)... (attempt \(attempt + 1)/\(maxAttempts))")
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }

            default:
                print("⚠️ Unknown status: \(jobStatus.status)")
                if attempt < maxAttempts - 1 {
                    print("  Continuing to poll... (attempt \(attempt + 1)/\(maxAttempts))")
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                } else {
                    throw PyannoteCloudError.unknownStatus(jobStatus.status)
                }
            }
        }

        throw PyannoteCloudError.timeout
    }
}

private struct UploadURLResponse: Codable {
    let url: String
}

private struct JobResponse: Codable {
    let jobId: String
}

private struct JobStatusResponse: Codable {
    let jobId: String
    let status: String
    let output: DiarizationOutput?
    let error: String?
}

private struct DiarizationOutput: Codable {
    let diarization: [PyannoteSegment]
    let confidence: ConfidenceScore?
    let error: String?
    let warning: String?
}

private struct ConfidenceScore: Codable {
    let score: [Double]
    let resolution: Double
}


enum PyannoteCloudError: LocalizedError {
    case apiKeyNotConfigured
    case invalidURL
    case uploadFailed(String)
    case diarizationFailed(String)
    case pollingFailed(String)
    case noOutput
    case unknownStatus(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "Pyannote.ai API key is not configured. Set PYANNOTE_API_KEY environment variable."
        case .invalidURL:
            return "Invalid API URL"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .diarizationFailed(let message):
            return "Diarization failed: \(message)"
        case .pollingFailed(let message):
            return "Polling failed: \(message)"
        case .noOutput:
            return "Job succeeded but no output was returned"
        case .unknownStatus(let status):
            return "Unknown job status: \(status)"
        case .timeout:
            return "Diarization timeout - job took too long to complete"
        }
    }
}
