//
//  AudioPlayerView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct AudioPlayerView: View {
    @ObservedObject var playerManager: AudioPlayerManager

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 2) {
                ForEach(0..<40) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(playerManager.isPlaying ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 3, height: CGFloat.random(in: 8...32))
                }
            }
            .frame(height: 40)

            VStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { playerManager.currentTime },
                        set: { playerManager.seek(to: $0) }
                    ),
                    in: 0...max(playerManager.duration, 1)
                )
                .tint(Color.accentColor)
                .disabled(!playerManager.isPlaying && playerManager.currentTime == 0)

                HStack {
                    Text(formatTime(playerManager.currentTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Text(formatTime(playerManager.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 24) {
                Button {
                    playerManager.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!playerManager.isPlaying && playerManager.currentTime == 0)
                .opacity((!playerManager.isPlaying && playerManager.currentTime == 0) ? 0.4 : 1)

                Button {
                    if playerManager.isPlaying {
                        playerManager.pause()
                    } else {
                        playerManager.play()
                    }
                } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .scaleEffect(playerManager.isPlaying ? 1.0 : 1.0)
                .animation(.spring(response: 0.3), value: playerManager.isPlaying)
            }

            if let error = playerManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
