//
//  TranscriptionSegment.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import Foundation

struct TranscriptionSegment: Codable {
    let text: String
    let startTime: TimeInterval
    let duration: TimeInterval
    let confidence: Float

    var endTime: TimeInterval {
        startTime + duration
    }
}
