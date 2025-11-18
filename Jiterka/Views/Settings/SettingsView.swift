//
//  SettingsView.swift
//  Jiterka
//
//  Settings view for API configuration
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = JiteraBoostConfig.apiKey
    @State private var showApiKey: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image("JiteraLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)

                            Text("JiteraBoost API")
                                .font(.headline)
                        }

                        Text("Connect your Jitera project to enable AI-powered transcription cleanup, summarization, and document sync.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                if showApiKey {
                                    TextField("Enter your JiteraBoost API key", text: $apiKey)
                                        .textFieldStyle(.plain)
                                } else {
                                    SecureField("Enter your JiteraBoost API key", text: $apiKey)
                                        .textFieldStyle(.plain)
                                }

                                Button {
                                    showApiKey.toggle()
                                } label: {
                                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(showApiKey ? "Hide API key" : "Show API key")
                            }
                            .padding(10)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )

                            if apiKey.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Get your API key from your Jitera project settings")
                                        .font(.caption)
                                }
                                .foregroundStyle(.blue)
                            }
                        }

                        HStack(spacing: 8) {
                            Circle()
                                .fill(apiKey.isEmpty ? Color.gray : Color.green)
                                .frame(width: 8, height: 8)

                            Text(apiKey.isEmpty ? "Not configured" : "Connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Spacer()

                            Button {
                                saveApiKey()
                            } label: {
                                Text("Save")
                                    .frame(width: 100)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKey == JiteraBoostConfig.apiKey)

                            if !apiKey.isEmpty && apiKey != JiteraBoostConfig.apiKey {
                                Button("Cancel") {
                                    apiKey = JiteraBoostConfig.apiKey
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 400)
    }

    private func saveApiKey() {
        JiteraBoostConfig.apiKey = apiKey
        dismiss()
    }
}
