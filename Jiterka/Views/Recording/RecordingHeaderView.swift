//
//  RecordingHeaderView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct RecordingHeaderView: View {
    let recording: Recording
    let onSync: () -> Void
    let onShowSyncPanel: () -> Void

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
                EditableText(
                    text: recording.name,
                    font: .title3,
                    fontWeight: .semibold
                ) { newName in
                    recording.name = newName
                }

                HStack(spacing: 12) {
                    Label(recording.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label(recording.duration.formattedDurationReadable(), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            SyncButton(
                recording: recording,
                onSync: onSync,
                onShowSyncPanel: onShowSyncPanel,
                style: .regular
            )
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
}
