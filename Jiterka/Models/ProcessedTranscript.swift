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

    var cleanedLines: [SpeakerLine]?
    var cleanedFullText: String?
    var cleanupError: String?

    init(lines: [SpeakerLine], fullText: String, speakerCount: Int, cleanedLines: [SpeakerLine]? = nil, cleanedFullText: String? = nil, cleanupError: String? = nil) {
        self.lines = lines
        self.fullText = fullText
        self.speakerCount = speakerCount
        self.processedAt = Date()
        self.cleanedLines = cleanedLines
        self.cleanedFullText = cleanedFullText
        self.cleanupError = cleanupError
    }

    var isEmpty: Bool {
        lines.isEmpty
    }

    var hasCleanedTranscript: Bool {
        cleanedLines != nil && !(cleanedLines?.isEmpty ?? true)
    }
}
