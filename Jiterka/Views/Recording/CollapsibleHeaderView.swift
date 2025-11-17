//
//  CollapsibleHeaderView.swift
//  Jiterka
//
//  Expandable/collapsible header for recording detail view
//

import SwiftUI

struct CollapsibleHeaderView: View {
    let recording: Recording
    let isSyncing: Bool
    let onSync: () -> Void
    @Binding var isExpanded: Bool
    @StateObject private var playerManager = AudioPlayerManager()
    @State private var isHoveringCollapsedHeader = false

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                VStack(spacing: 20) {
                    RecordingHeaderView(
                        recording: recording,
                        isSyncing: isSyncing,
                        onSync: onSync
                    )

                    if recording.fileURL != nil {
                        AudioPlayerView(playerManager: playerManager)
                    }
                }
                .padding(20)
                .background(Color(NSColor.windowBackgroundColor))
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recording.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        Text(recording.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)

                    SyncButton(
                        recording: recording,
                        isSyncing: isSyncing,
                        onSync: onSync,
                        style: .compact
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                }
                .onHover { hovering in
                    isHoveringCollapsedHeader = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .help("Expand header")
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if isExpanded {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Collapse header")
                .transition(.opacity)
            }
        }
        .onAppear {
            loadRecordingAudio()
        }
        .onChange(of: recording.id) {
            loadRecordingAudio()
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }

    private func loadRecordingAudio() {
        playerManager.cleanup()

        if let fileURLPath = recording.fileURL {
            let fileURL = URL(fileURLWithPath: fileURLPath)
            playerManager.loadAudio(from: fileURL)
        }
    }
}
