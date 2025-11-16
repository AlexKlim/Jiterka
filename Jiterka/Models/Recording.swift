//
//  Recording.swift
//  Jiterka
//
//  Created by Alex K on 11/12/25.
//

import Foundation
import SwiftData

@Model
final class Recording {
    var timestamp: Date
    var duration: TimeInterval
    var name: String
    var fileURL: String?
    var transcriptData: Data?
    var isTranscribed: Bool = false
    var summary: String?
    var isSummarized: Bool = false
    var isSynced: Bool = false

    init(timestamp: Date, duration: TimeInterval, name: String, fileURL: String? = nil) {
        self.timestamp = timestamp
        self.duration = duration
        self.name = name
        self.fileURL = fileURL
        self.transcriptData = nil
        self.isTranscribed = false
        self.summary = nil
        self.isSummarized = false
        self.isSynced = false
    }

    var transcript: ProcessedTranscript? {
        get {
            guard let data = transcriptData else { return nil }
            return try? JSONDecoder().decode(ProcessedTranscript.self, from: data)
        }
        set {
            transcriptData = try? JSONEncoder().encode(newValue)
            isTranscribed = (newValue != nil)
        }
    }
}
