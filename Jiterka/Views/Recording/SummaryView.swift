//
//  SummaryView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI
import MarkdownUI
import AppKit

struct SummaryView: View {
    let summary: String?
    @State private var showCopiedConfirmation = false

    var body: some View {
        ScrollView {
            if let summary = summary {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.accentColor)

                            Text("AI Summary")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                copySummaryToClipboard(summary)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(showCopiedConfirmation ? "Copied" : "Copy")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(showCopiedConfirmation ? .green : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Copy summary to clipboard")
                        }

                        Markdown(summary)
                            .textSelection(.enabled)
                            .markdownTextStyle(\.text) {
                                ForegroundColor(.primary)
                                FontSize(14)
                            }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                .padding(20)
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle.fill",
                    title: "No Summary Available",
                    message: "Summary generation may have failed or was skipped. Try regenerating the transcript.",
                    iconColor: .orange
                )
            }
        }
    }

    private func copySummaryToClipboard(_ summary: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summary, forType: .string)

        withAnimation {
            showCopiedConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedConfirmation = false
            }
        }
    }
}
