//
//  SyncButton.swift
//  Jiterka
//
//  Reusable sync button component
//

import SwiftUI

struct SyncButton: View {
    let recording: Recording
    let isSyncing: Bool
    let onSync: () -> Void
    let style: Style

    @State private var isHovering = false

    enum Style {
        case compact
        case regular

        var iconSize: CGFloat {
            switch self {
            case .compact: return 14
            case .regular: return 18
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .compact: return 12
            case .regular: return 14
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: return 10
            case .regular: return 14
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .compact: return 6
            case .regular: return 10
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 6
            case .regular: return 8
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact: return 5
            case .regular: return 6
            }
        }
    }

    var body: some View {
        CursorButton(
            action: onSync,
            isDisabled: isSyncing || !JiteraBoostConfig.isConfigured || recording.summary == nil || recording.transcript == nil,
            tooltip: syncButtonTooltip(),
            onHoverChange: { hovering in
                isHovering = hovering
            }
        ) {
            HStack(spacing: style.spacing) {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: style.iconSize, height: style.iconSize)
                } else {
                    Image("JiteraLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: style.iconSize, height: style.iconSize)
                }
                Text(buttonText())
                    .font(.system(size: style.fontSize, weight: .medium))
                    .animation(.easeInOut(duration: 0.2), value: buttonText())
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(buttonBackgroundColor())
                    .animation(.easeInOut(duration: 0.2), value: buttonBackgroundColor())
            )
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .strokeBorder(buttonBorderColor(), lineWidth: 1)
                    .animation(.easeInOut(duration: 0.2), value: buttonBorderColor())
            )
        }
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
}
