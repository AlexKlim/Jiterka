//
//  RecordingControlsView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject var recordingManager: ScreenCaptureAudioManager
    let onStartRecording: () -> Void
    @State private var showSettings = false
    @AppStorage("JiteraBoostAPIKey") private var apiKey: String = ""

    private var isConfigured: Bool {
        !apiKey.isEmpty
    }

    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Spacer()
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            Image("JiteraLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .padding(.bottom, 10)

            Text("Meeting Audio Recorder")
                .font(.largeTitle)
                .fontWeight(.bold)

            if !isConfigured {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("API Key Required")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }

                    Text("Configure your JiteraBoost API key in Settings to start recording")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showSettings = true
                    } label: {
                        Label("Open Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .frame(maxWidth: 400)
            }

            if isConfigured {
                Button {
                    onStartRecording()
                } label: {
                    Label("Start Recording", systemImage: "record.circle")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
