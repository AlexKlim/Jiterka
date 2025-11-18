//
//  SyncCoordinator.swift
//  Jiterka
//
//  Coordinates syncing across recordings to prevent concurrent syncs
//

import Foundation
import Combine
import SwiftData

class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    @Published private(set) var syncingRecordingId: PersistentIdentifier?

    private init() {}

    @MainActor
    func canStartSync(for recordingId: PersistentIdentifier) -> Bool {
        return syncingRecordingId == nil || syncingRecordingId == recordingId
    }

    @MainActor
    func startSync(for recordingId: PersistentIdentifier) {
        syncingRecordingId = recordingId
    }

    @MainActor
    func endSync(for recordingId: PersistentIdentifier) {
        if syncingRecordingId == recordingId {
            syncingRecordingId = nil
        }
    }

    var isSyncing: Bool {
        syncingRecordingId != nil
    }

    func isSyncingRecording(_ recordingId: PersistentIdentifier) -> Bool {
        syncingRecordingId == recordingId
    }
}
