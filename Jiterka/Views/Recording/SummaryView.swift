//
//  SummaryView.swift
//  Jiterka
//
//  Created by Alex K on 11/14/25.
//

import SwiftUI

struct SummaryView: View {
    let summary: String?

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
                        }

                        Text(summary)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineSpacing(6)
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
                    icon: "doc.text.magnifyingglass",
                    title: "No Summary Yet",
                    message: "Summary will be generated from the transcript",
                    iconColor: .secondary
                )
            }
        }
    }
}
