//
//  AudioPlayerView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct AudioPlayerView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @State private var isHoveringPlayPause = false
    @State private var isHoveringStop = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button {
                    if playerManager.isPlaying {
                        playerManager.pause()
                    } else {
                        playerManager.play()
                    }
                } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.accentColor)
                        )
                        .scaleEffect(isHoveringPlayPause ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringPlayPause = hovering
                    }
                }

                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { playerManager.currentTime },
                            set: { playerManager.seek(to: $0) }
                        ),
                        in: 0...max(playerManager.duration, 1)
                    )
                    .tint(Color.accentColor)
                    .disabled(!playerManager.isPlaying && playerManager.currentTime == 0)
                    .controlSize(.small)

                    HStack {
                        Text(formatTime(playerManager.currentTime))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Spacer()

                        Text(formatTime(playerManager.duration))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Button {
                    playerManager.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .scaleEffect(isHoveringStop ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(!playerManager.isPlaying && playerManager.currentTime == 0)
                .opacity((!playerManager.isPlaying && playerManager.currentTime == 0) ? 0.3 : 1)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringStop = hovering
                    }
                }
            }
            .padding(16)

            if let error = playerManager.errorMessage {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.05))
            }
        }
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
