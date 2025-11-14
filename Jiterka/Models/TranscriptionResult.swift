//
//  TranscriptionResult.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import Foundation

struct TranscriptionResult: Codable {
    let fullText: String
    let segments: [TranscriptionSegment]

    var isEmpty: Bool {
        fullText.isEmpty
    }
}
