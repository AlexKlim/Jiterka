//
//  ProcessedTranscript.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import Foundation

struct ProcessedTranscript: Codable {
    let lines: [SpeakerLine]
    let fullText: String
    let speakerCount: Int
    let processedAt: Date

    init(lines: [SpeakerLine], fullText: String, speakerCount: Int) {
        self.lines = lines
        self.fullText = fullText
        self.speakerCount = speakerCount
        self.processedAt = Date()
    }

    var isEmpty: Bool {
        lines.isEmpty
    }
}
