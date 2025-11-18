//
//  RecordingDetailView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI
import SwiftData
import AppKit

struct RecordingDetailView: View {
    let recording: Recording
    var recordingManager: ScreenCaptureAudioManager? = nil
    var onStopRecording: (() -> Void)? = nil
    var onRequestDelete: (() -> Void)? = nil

    @StateObject private var viewModel = RecordingDetailViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .summary
    @State private var isHeaderExpanded = false
    @State private var showSyncPanel = false

    private var isRecording: Bool {
        recordingManager?.isRecording ?? false
    }

    enum Tab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
        case rawTranscript = "Raw Transcript"
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    CollapsibleHeaderView(
                        recording: recording,
                        onSync: {
                            showSyncPanel = true
                            Task {
                                await viewModel.syncRecording(recording, modelContext: modelContext)
                            }
                        },
                        onShowSyncPanel: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSyncPanel = true
                            }
                        },
                        isExpanded: $isHeaderExpanded
                    )

                    Divider()

                    if !isRecording {
                        tabBar
                        Divider()
                    }
                }

                if isRecording {
                    recordingInProgressView
                } else {
                    RecordingTabContentView(
                        recording: recording,
                        selectedTab: selectedTab
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showSyncPanel {
                Divider()

                SyncProgressPanel(
                    recordingName: viewModel.syncRecordingName,
                    recordingDate: viewModel.syncRecordingDate,
                    isSyncing: viewModel.isSyncing,
                    messages: viewModel.syncMessages,
                    isVisible: $showSyncPanel
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isRecording {
                isHeaderExpanded = true
            }
        }
        .onChange(of: isRecording) {
            if isRecording {
                isHeaderExpanded = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await viewModel.regenerateTranscript(for: recording, modelContext: modelContext)
                    }
                } label: {
                    if viewModel.isRegenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRegenerating || recording.fileURL == nil)
                .help("Regenerate transcription and speaker diarization")
            }

            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    onRequestDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete this recording")
            }
        }
        .alert("Sync Failed", isPresented: .constant(viewModel.syncError != nil)) {
            Button("OK", role: .cancel) {
                viewModel.syncError = nil
            }
        } message: {
            if let error = viewModel.syncError {
                Text(error)
            }
        }
    }

    private var recordingInProgressView: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                        Text("Recording")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }

                    if let duration = recordingManager?.recordingDuration {
                        Text(duration.formattedDuration())
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)

                if let error = recordingManager?.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Button {
                Task {
                    await recordingManager?.stopRecording()
                    onStopRecording?()
                }
            } label: {
                Label("Stop Recording", systemImage: "stop.fill")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tabIcon(for: tab))
                                .font(.system(size: 14, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func tabIcon(for tab: Tab) -> String {
        switch tab {
        case .summary:
            return "doc.text.fill"
        case .transcript:
            return "sparkles.rectangle.stack.fill"
        case .rawTranscript:
            return "text.bubble.fill"
        }
    }
}
