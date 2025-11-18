//
//  SyncMessage.swift
//  Jiterka
//
//  Model for sync progress messages
//

import Foundation
import SwiftUI

struct SyncMessage: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let text: String
    var type: MessageType
    var aiResponse: String?

    enum MessageType {
        case info
        case inProgress
        case success
        case error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .inProgress: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return .blue
            case .inProgress: return .orange
            case .success: return .green
            case .error: return .red
            }
        }

        var backgroundColor: Color {
            switch self {
            case .info: return Color.blue.opacity(0.05)
            case .inProgress: return Color.orange.opacity(0.05)
            case .success: return Color.green.opacity(0.05)
            case .error: return Color.red.opacity(0.05)
            }
        }
    }
}
