//
//  DiarizationManager.swift
//  Jiterka
//
//  FluidAudio for speaker diarization
//

import Foundation
import Combine
import FluidAudio

enum DiarizationMode {
    case fluidAudio
    case fluidAudioWithFallback
    case pythonServer
    case pyannoteCloud
}

@MainActor
class DiarizationManager: ObservableObject {
    private var diarizerManager: OfflineDiarizerManager?

    // Diarization runs on the device by default, so the audio never leaves the
    // machine. .pythonServer uses the local pyannote server in
    // PyannoteDiarization/, and .pyannoteCloud calls the hosted pyannote.ai API
    // if you want to compare the results.
    private let mode: DiarizationMode = .fluidAudioWithFallback

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
        switch mode {
        case .pythonServer:
            print("🐍 Using local Python server...")
            return try await diarizePython(audioURL: audioURL)

        case .pyannoteCloud:
            print("☁️ Using pyannote.ai cloud API...")
            return try await diarizePyannoteCloud(audioURL: audioURL)

        case .fluidAudio:
            print("📱 Using FluidAudio (local CoreML)...")
            return try await diarizeFluidAudio(audioURL: audioURL, useFallback: false)

        case .fluidAudioWithFallback:
            print("📱 Using FluidAudio with Python fallback...")
            return try await diarizeFluidAudio(audioURL: audioURL, useFallback: true)
        }
    }

    private func diarizeFluidAudio(audioURL: URL, useFallback: Bool) async throws -> DiarizationResult {
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

            let uniqueSpeakers = Set(result.segments.map { $0.speakerId })
            print("  Unique speakers detected: \(uniqueSpeakers.count)")
            print("  Speaker IDs: \(uniqueSpeakers.sorted())")

            var speakerCounts: [String: Int] = [:]
            var speakerDurations: [String: TimeInterval] = [:]
            for segment in result.segments {
                speakerCounts[segment.speakerId, default: 0] += 1
                speakerDurations[segment.speakerId, default: 0] += TimeInterval(segment.endTimeSeconds - segment.startTimeSeconds)
            }

            let speakerSegments = result.segments.map { segment in
                SpeakerSegment(
                    speakerId: segment.speakerId,
                    startTime: TimeInterval(segment.startTimeSeconds),
                    endTime: TimeInterval(segment.endTimeSeconds)
                )
            }

            if useFallback {
                do {
                    let pythonResult = try await tryPythonDiarization(audioURL: audioURL)
                    if pythonResult.numSpeakers > 1 {
                        print("✅ Python diarization found \(pythonResult.numSpeakers) speakers")

                        let pythonSegments = pythonResult.segments.map { segment in
                            SpeakerSegment(
                                speakerId: segment.speaker,
                                startTime: TimeInterval(segment.start),
                                endTime: TimeInterval(segment.end)
                            )
                        }

                        return DiarizationResult(segments: pythonSegments)
                    }
                } catch {
                    print("⚠️ Python diarization fallback failed: \(error.localizedDescription)")
                }
            }

            return DiarizationResult(segments: speakerSegments)
        } catch {
            throw DiarizationError.processingFailed(error)
        }
    }

    private func diarizePython(audioURL: URL) async throws -> DiarizationResult {
        let service = PyannoteDiarizationService.shared

        guard await service.isServerAvailable() else {
            print("  ❌ Python server is not available")
            throw PyannoteDiarizationError.serverNotAvailable
        }

        let pythonResult = try await service.diarize(audioPath: audioURL.path)

        print("  ✅ Diarization completed!")
        print("  Number of speakers: \(pythonResult.numSpeakers)")
        print("  Total segments: \(pythonResult.segments.count)")

        var speakerCounts: [String: Int] = [:]
        var speakerDurations: [String: TimeInterval] = [:]
        for segment in pythonResult.segments {
            speakerCounts[segment.speaker, default: 0] += 1
            speakerDurations[segment.speaker, default: 0] += TimeInterval(segment.end - segment.start)
        }

        let segments = pythonResult.segments.map { segment in
            SpeakerSegment(
                speakerId: segment.speaker,
                startTime: TimeInterval(segment.start),
                endTime: TimeInterval(segment.end)
            )
        }

        return DiarizationResult(segments: segments)
    }

    private func diarizePyannoteCloud(audioURL: URL) async throws -> DiarizationResult {
        let service = PyannoteCloudService.shared

        guard service.isConfigured else {
            print("  ❌ Pyannote.ai API key not configured")
            throw PyannoteCloudError.apiKeyNotConfigured
        }

        let result = try await service.diarize(audioURL: audioURL)

        print("  ✅ Cloud diarization completed!")
        print("  Number of speakers: \(result.numSpeakers)")
        print("  Total segments: \(result.segments.count)")

        let segments = result.segments.map { segment in
            SpeakerSegment(
                speakerId: segment.speaker,
                startTime: TimeInterval(segment.start),
                endTime: TimeInterval(segment.end)
            )
        }

        return DiarizationResult(segments: segments)
    }

    private func tryPythonDiarization(audioURL: URL) async throws -> PyannoteDiarizationResponse {
        let service = PyannoteDiarizationService.shared

        guard await service.isServerAvailable() else {
            throw PyannoteDiarizationError.serverNotAvailable
        }

        return try await service.diarize(audioPath: audioURL.path)
    }
}
