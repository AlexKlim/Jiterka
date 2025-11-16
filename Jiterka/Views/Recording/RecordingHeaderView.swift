//
//  RecordingHeaderView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct RecordingHeaderView: View {
    let recording: Recording
    let isSyncing: Bool
    let onSync: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(recording.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label(recording.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label(formatDuration(recording.duration), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            CursorButton(
                action: onSync,
                isDisabled: isSyncing || !JiteraBoostConfig.isConfigured || recording.summary == nil || recording.transcript == nil,
                tooltip: syncButtonTooltip(),
                onHoverChange: { hovering in
                    isHovering = hovering
                }
            ) {
                HStack(spacing: 6) {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 18, height: 18)
                    } else {
                        Image("JiteraLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                    Text(buttonText())
                        .font(.system(size: 14, weight: .medium))
                        .animation(.easeInOut(duration: 0.2), value: buttonText())
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonBackgroundColor())
                        .animation(.easeInOut(duration: 0.2), value: buttonBackgroundColor())
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(buttonBorderColor(), lineWidth: 1)
                        .animation(.easeInOut(duration: 0.2), value: buttonBorderColor())
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func buttonText() -> String {
        if isSyncing {
            return "Syncing..."
        } else if recording.isSynced {
            return isHovering ? "Re-Sync" : "Synced"
        } else {
            return "Sync"
        }
    }

    private func buttonBackgroundColor() -> Color {
        if recording.isSynced && !isSyncing && !isHovering {
            return Color.green.opacity(0.1)
        } else {
            return Color.accentColor.opacity(0.1)
        }
    }

    private func buttonBorderColor() -> Color {
        if recording.isSynced && !isSyncing && !isHovering {
            return Color.green.opacity(0.3)
        } else {
            return Color.accentColor.opacity(0.3)
        }
    }

    private func syncButtonTooltip() -> String {
        if !JiteraBoostConfig.isConfigured {
            return "JiteraBoost API key not configured"
        } else if recording.summary == nil || recording.transcript == nil {
            return "Summary and transcript required for sync"
        } else if isSyncing {
            return "Syncing to Jitera..."
        } else if recording.isSynced {
            return "Re-sync with Jitera"
        } else {
            return "Sync with Jitera"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
