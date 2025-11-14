//
//  SpeakerLine.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import Foundation

struct SpeakerLine: Codable, Identifiable {
    let id = UUID()
    var speakerId: String
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval

    enum CodingKeys: String, CodingKey {
        case speakerId, text, startTime, endTime
    }
}
