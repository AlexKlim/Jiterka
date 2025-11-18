//
//  SyncProgressPanel.swift
//  Jiterka
//
//  Right inspector panel showing sync progress and AI responses
//

import SwiftUI

struct SyncProgressPanel: View {
    let recordingName: String
    let recordingDate: Date
    let isSyncing: Bool
    let messages: [SyncMessage]
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                        Text("Sync Progress")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(recordingName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(recordingDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close panel")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if messages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                messageRow(message, isLatest: index == messages.count - 1)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) {
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No sync activity")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Click sync to see progress")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func messageRow(_ message: SyncMessage, isLatest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: message.type.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(message.type.color)

                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                if message.type == .inProgress && isLatest {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 10, height: 10)
                }
            }

            Text(message.text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            if let aiResponse = message.aiResponse {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Response:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(aiResponse)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(10)
        .background(message.type.backgroundColor)
        .cornerRadius(8)
    }
}
