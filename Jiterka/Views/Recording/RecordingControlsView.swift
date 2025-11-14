//
//  RecordingControlsView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject var recordingManager: ScreenCaptureAudioManager
    let onStopRecording: () async -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Text("Meeting Audio Recorder")
                .font(.largeTitle)
                .fontWeight(.bold)

            if recordingManager.isRecording {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                        Text("Recording")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }

                    Text(formatDuration(recordingManager.recordingDuration))
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }

            if let error = recordingManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            HStack(spacing: 16) {
                if recordingManager.isRecording {
                    Button {
                        Task {
                            await recordingManager.stopRecording()
                            await onStopRecording()
                        }
                    } label: {
                        Label("Stop Recording", systemImage: "stop.fill")
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                } else {
                    Button {
                        Task {
                            await recordingManager.startRecording()
                        }
                    } label: {
                        Label("Start Recording", systemImage: "record.circle")
                            .frame(maxWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
