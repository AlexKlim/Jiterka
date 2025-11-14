//
//  DiarizationResult.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import Foundation

struct DiarizationResult: Codable {
    let segments: [SpeakerSegment]

    var speakerCount: Int {
        Set(segments.map { $0.speakerId }).count
    }

    var isEmpty: Bool {
        segments.isEmpty
    }
}
