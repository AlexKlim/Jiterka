//
//  JiteraBoostConfig.swift
//  Jiterka
//
//  Configuration for JiteraBoost AI service
//

import Foundation

enum JiteraBoostConfig {
    private static let userDefaultsKey = "JiteraBoostAPIKey"

    static var apiKey: String {
        get {
            UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
        }
    }

    static var isConfigured: Bool {
        !apiKey.isEmpty
    }

    static func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
