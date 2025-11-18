//
//  JiteraBoostClient.swift
//  Jiterka
//
//  Base client for JiteraBoost AI API
//

import Foundation

@MainActor
class JiteraBoostClient {
    let apiURL = URL(string: "https://ai.jitera.app/v1/chat/completions")!
    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func makeRequest(
        systemPrompt: String,
        userPrompt: String,
        responseSchema: [String: Any] = [:]
    ) async throws -> JiteraResponse {
        var requestDict: [String: Any] = [
            "model": "jitera/document_agent",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
//            "com.jitera.boost": [
//                "workflow": [
//                    "values": [
//                        "model": "claude-sonnet-4"
//                    ]
//                ]
//            ]
        ]

        if !responseSchema.isEmpty {
            requestDict["response_format"] = responseSchema
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes
        request.httpBody = try JSONSerialization.data(withJSONObject: requestDict)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JiteraBoostError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ JiteraBoost API error (\(httpResponse.statusCode)): \(errorMessage)")
            throw JiteraBoostError.apiError(httpResponse.statusCode, errorMessage)
        }

        let jiteraResponse = try JSONDecoder().decode(JiteraResponse.self, from: data)

        if let error = jiteraResponse.error {
            print("❌ JiteraBoost returned error: \(error)")
            throw JiteraBoostError.apiError(httpResponse.statusCode, error)
        }

        guard jiteraResponse.choices != nil else {
            throw JiteraBoostError.noResult
        }

        return jiteraResponse
    }
}
