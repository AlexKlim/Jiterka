//
//  ScreenCaptureAudioManager.swift
//  Jiterka
//
//  ScreenCaptureKit-based audio recording with microphone
//

import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation
import Combine

@MainActor
class ScreenCaptureAudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var lastRecordingURL: URL?

    private var stream: SCStream?
    private var systemAssetWriter: AVAssetWriter?
    private var systemAssetWriterInput: AVAssetWriterInput?
    private var microphoneAssetWriter: AVAssetWriter?
    private var microphoneAssetWriterInput: AVAssetWriterInput?
    private var currentFileURL: URL?
    private var systemAudioURL: URL?
    private var microphoneAudioURL: URL?
    private var recordingStartTime: Date?
    private var timer: Timer?
    private var hasStartedSystemSession = false
    private var hasStartedMicrophoneSession = false

    func getRecordingsDirectoryPath() -> String? {
        return try? getRecordingsDirectory().path
    }

    func startRecording() async {
        guard !isRecording else { return }

        do {
            let recordingsURL = try getRecordingsDirectory()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let dateString = dateFormatter.string(from: Date())
            let fileName = "Meeting_\(dateString).m4a"
            let fileURL = recordingsURL.appendingPathComponent(fileName)
            let systemFileName = "Meeting_\(dateString)_system.caf"
            let micFileName = "Meeting_\(dateString)_mic.caf"
            let systemURL = recordingsURL.appendingPathComponent(systemFileName)
            let micURL = recordingsURL.appendingPathComponent(micFileName)
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else {
                throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No display found"])
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])

            let streamConfig = SCStreamConfiguration()
            streamConfig.capturesAudio = true
            streamConfig.captureMicrophone = true
            streamConfig.sampleRate = 48000
            streamConfig.channelCount = 2
            streamConfig.queueDepth = 8
            streamConfig.width = 100
            streamConfig.height = 100
            streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
            guard let stream = stream else {
                throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create stream"])
            }

            let audioQueue = DispatchQueue(label: "com.jitera.jiterka.audio", qos: .userInitiated)
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)

            let micQueue = DispatchQueue(label: "com.jitera.jiterka.microphone", qos: .userInitiated)
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: micQueue)

            let videoQueue = DispatchQueue(label: "com.jitera.jiterka.video", qos: .userInitiated)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)

            currentFileURL = fileURL
            systemAudioURL = systemURL
            microphoneAudioURL = micURL

            if FileManager.default.fileExists(atPath: systemURL.path) {
                try FileManager.default.removeItem(at: systemURL)
            }
            if FileManager.default.fileExists(atPath: micURL.path) {
                try FileManager.default.removeItem(at: micURL)
            }

            systemAssetWriter = try AVAssetWriter(outputURL: systemURL, fileType: .caf)
            microphoneAssetWriter = try AVAssetWriter(outputURL: micURL, fileType: .caf)

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000.0,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]

            systemAssetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            systemAssetWriterInput?.expectsMediaDataInRealTime = true

            let micAudioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]

            microphoneAssetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: micAudioSettings)
            microphoneAssetWriterInput?.expectsMediaDataInRealTime = true

            if let input = systemAssetWriterInput, systemAssetWriter?.canAdd(input) == true {
                systemAssetWriter?.add(input)
            }
            if let input = microphoneAssetWriterInput, microphoneAssetWriter?.canAdd(input) == true {
                microphoneAssetWriter?.add(input)
            }

            systemAssetWriter?.startWriting()
            microphoneAssetWriter?.startWriting()

            hasStartedSystemSession = false
            hasStartedMicrophoneSession = false

            try await stream.startCapture()

            isRecording = true
            recordingStartTime = Date()
            startTimer()
            errorMessage = nil

        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            cleanup()
        }
    }

    func stopRecording() async {
        guard isRecording else { return }

        if let stream = stream {
            try? await stream.stopCapture()
        }

        systemAssetWriterInput?.markAsFinished()
        microphoneAssetWriterInput?.markAsFinished()

        await systemAssetWriter?.finishWriting()
        await microphoneAssetWriter?.finishWriting()

        systemAssetWriter = nil
        systemAssetWriterInput = nil
        microphoneAssetWriter = nil
        microphoneAssetWriterInput = nil
        stream = nil
        hasStartedSystemSession = false
        hasStartedMicrophoneSession = false
        isRecording = false
        
        stopTimer()
        recordingDuration = 0

        if let systemURL = systemAudioURL,
           let micURL = microphoneAudioURL,
           let outputURL = currentFileURL {
            do {
                try await mergeAudioFiles(systemURL: systemURL, microphoneURL: micURL, outputURL: outputURL)

                try? FileManager.default.removeItem(at: systemURL)
                try? FileManager.default.removeItem(at: micURL)

                lastRecordingURL = outputURL
            } catch {
                errorMessage = "Failed to merge audio: \(error.localizedDescription)"
                lastRecordingURL = systemURL
            }
        }
    }

    private func getRecordingsDirectory() throws -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Jiterka"
        let appDirectory = appSupportURL.appendingPathComponent(appName)
        let recordingsPath = appDirectory.appendingPathComponent("Recordings")

        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }

        return recordingsPath
    }

    private func mergeAudioFiles(systemURL: URL, microphoneURL: URL, outputURL: URL) async throws {
        guard FileManager.default.fileExists(atPath: systemURL.path) else {
            throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "System audio file not found"])
        }

        guard FileManager.default.fileExists(atPath: microphoneURL.path) else {
            throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Microphone audio file not found"])
        }

        let composition = AVMutableComposition()

        guard let compositionTrack1 = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track 1"])
        }

        guard let compositionTrack2 = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track 2"])
        }

        let systemAsset = AVURLAsset(url: systemURL)
        let micAsset = AVURLAsset(url: microphoneURL)

        guard let systemTrack = try await systemAsset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No system audio track found"])
        }

        guard let micTrack = try await micAsset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No microphone audio track found"])
        }

        let systemDuration = try await systemAsset.load(.duration)
        let micDuration = try await micAsset.load(.duration)

        try compositionTrack1.insertTimeRange(
            CMTimeRange(start: .zero, duration: systemDuration),
            of: systemTrack,
            at: .zero
        )

        try compositionTrack2.insertTimeRange(
            CMTimeRange(start: .zero, duration: micDuration),
            of: micTrack,
            at: .zero
        )

        let audioMix = AVMutableAudioMix()

        let systemInputParams = AVMutableAudioMixInputParameters(track: compositionTrack1)
        systemInputParams.setVolume(1.0, at: .zero)

        let micInputParams = AVMutableAudioMixInputParameters(track: compositionTrack2)
        micInputParams.setVolume(1.0, at: .zero)

        audioMix.inputParameters = [systemInputParams, micInputParams]

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NSError(domain: "ScreenCaptureAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        exportSession.audioMix = audioMix

        try await exportSession.export(to: outputURL, as: .m4a)
    }

    private func cleanup() {
        stream = nil
        systemAssetWriter = nil
        systemAssetWriterInput = nil
        microphoneAssetWriter = nil
        microphoneAssetWriterInput = nil
        hasStartedSystemSession = false
        hasStartedMicrophoneSession = false
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingStartTime = nil
    }
}

// MARK: - SCStreamDelegate

extension ScreenCaptureAudioManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "Stream error: \(error.localizedDescription)"
            self.isRecording = false
            self.stopTimer()
        }
    }
}

// MARK: - SCStreamOutput

extension ScreenCaptureAudioManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio || outputType == .microphone else { return }

        let isSystemAudio = (outputType == .audio)
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        Task { @MainActor in
            guard self.isRecording else { return }

            let writerInput: AVAssetWriterInput?
            let writer: AVAssetWriter?
            let hasStartedSession: Bool

            if isSystemAudio {
                writerInput = self.systemAssetWriterInput
                writer = self.systemAssetWriter
                hasStartedSession = self.hasStartedSystemSession
            } else {
                writerInput = self.microphoneAssetWriterInput
                writer = self.microphoneAssetWriter
                hasStartedSession = self.hasStartedMicrophoneSession
            }

            guard let input = writerInput, let assetWriter = writer else { return }

            if !hasStartedSession {
                assetWriter.startSession(atSourceTime: presentationTime)

                if isSystemAudio {
                    self.hasStartedSystemSession = true
                } else {
                    self.hasStartedMicrophoneSession = true
                }
            }

            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
}
