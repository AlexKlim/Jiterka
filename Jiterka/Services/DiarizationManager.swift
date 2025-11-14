//
//  DiarizationManager.swift
//  Jiterka
//
//  FluidAudio for speaker diarization
//

import Foundation
import Combine
import FluidAudio

@MainActor
class DiarizationManager: ObservableObject {
    private var diarizerManager: OfflineDiarizerManager?

    init() {}

    func prepareModels() async throws {
        do {
            let config = OfflineDiarizerConfig()
            let manager = OfflineDiarizerManager(config: config)
            try await manager.prepareModels()
            self.diarizerManager = manager
        } catch {
            throw DiarizationError.modelPreparationFailed(error)
        }
    }

    func diarize(audioURL: URL) async throws -> DiarizationResult {
        if diarizerManager == nil {
            try await prepareModels()
        }

        guard let manager = diarizerManager else {
            throw DiarizationError.managerNotInitialized
        }

        do {
            let result = try await manager.process(audioURL)

            print("🎯 FluidAudio diarization result:")
            print("  Total segments: \(result.segments.count)")

            let speakerSegments = result.segments.map { segment in
                SpeakerSegment(
                    speakerId: segment.speakerId,
                    startTime: TimeInterval(segment.startTimeSeconds),
                    endTime: TimeInterval(segment.endTimeSeconds)
                )
            }

            return DiarizationResult(segments: speakerSegments)
        } catch {
            throw DiarizationError.processingFailed(error)
        }
    }
}
