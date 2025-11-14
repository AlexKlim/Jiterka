//
//  AudioPlayerManager.swift
//  Jiterka
//
//  Audio playback manager
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    override init() {
        super.init()
    }

    func loadAudio(from url: URL) {
        do {
            print("Loading audio from: \(url.path)")

            guard FileManager.default.fileExists(atPath: url.path) else {
                errorMessage = "Audio file does not exist"
                print("File does not exist at: \(url.path)")
                return
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            print("Audio file size: \(fileSize) bytes")

            if fileSize == 0 {
                errorMessage = "Audio file is empty"
                return
            }

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            errorMessage = nil

            print("Audio loaded successfully. Duration: \(duration) seconds")
        } catch {
            errorMessage = "Failed to load audio: \(error.localizedDescription)"
            print("Error loading audio: \(error)")
            if let nsError = error as NSError? {
                print("Error code: \(nsError.code)")
                print("Error domain: \(nsError.domain)")
            }
        }
    }

    func play() {
        guard let player = audioPlayer else { return }

        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func cleanup() {
        stop()
        audioPlayer = nil
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = self.audioPlayer?.currentTime ?? 0
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            stopTimer()
            audioPlayer?.currentTime = 0
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "Playback error: \(error.localizedDescription)"
            }
            isPlaying = false
            stopTimer()
        }
    }
}
