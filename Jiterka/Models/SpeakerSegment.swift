//
//  SpeakerSegment.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import Foundation

struct SpeakerSegment: Codable, Identifiable {
    let id = UUID()
    let speakerId: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    var duration: TimeInterval {
        endTime - startTime
    }

    enum CodingKeys: String, CodingKey {
        case speakerId, startTime, endTime
    }
}
