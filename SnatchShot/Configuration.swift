//
//  Configuration.swift
//  SnatchShot
//
//  Created by Rushant on 16/09/25.
//

import Foundation

class Configuration {
    static let shared = Configuration()

    private init() {}

    // MARK: - Google Sign In
    var googleClientID: String {
        // Try to get from environment variable first
        if let envClientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] {
            return envClientID
        }

        // Try to get from build settings (Config.xcconfig)
        if let bundleID = Bundle.main.bundleIdentifier,
           let infoDict = Bundle.main.infoDictionary,
           let clientID = infoDict["GOOGLE_CLIENT_ID"] as? String {
            return clientID
        }

        // Try to get from Config.xcconfig file directly
        if let configClientID = getValue(for: "GOOGLE_CLIENT_ID") {
            return configClientID
        }

        // Fallback - replace with your actual client ID for development only
        // NEVER commit this to version control
        return "YOUR_DEVELOPMENT_CLIENT_ID_HERE"
    }

    // MARK: - Database API
    var databaseAPIBaseURL: String {
        if let envURL = ProcessInfo.processInfo.environment["DATABASE_API_BASE_URL"] {
            return envURL
        }

        if let configURL = getValue(for: "DATABASE_API_BASE_URL") {
            return configURL
        }

        return "http://13.221.107.42:4000/api"
    }

    var databaseAPITimeout: TimeInterval {
        if let envTimeout = ProcessInfo.processInfo.environment["DATABASE_API_TIMEOUT"],
           let timeout = Double(envTimeout) {
            return timeout
        }

        if let configTimeout = getValue(for: "DATABASE_API_TIMEOUT"),
           let timeout = Double(configTimeout) {
            return timeout
        }

        return 30.0
    }

    // MARK: - AppsFlyer
    var appsFlyerDevKey: String {
        if let envKey = ProcessInfo.processInfo.environment["APPSFLYER_DEV_KEY"] {
            return envKey
        }

        if let configKey = getValue(for: "APPSFLYER_DEV_KEY") {
            return configKey
        }

        // Fallback - AppsFlyer Dev Key
        return "359SBFQ3jWDaaixAkLLYQe"
    }

    var appleAppID: String {
        if let envID = ProcessInfo.processInfo.environment["APPLE_APP_ID"] {
            return envID
        }

        if let configID = getValue(for: "APPLE_APP_ID") {
            return configID
        }

        // Fallback - Apple App ID
        return "6752805655"
    }

    // MARK: - Mixpanel
    var mixpanelToken: String {
        if let envToken = ProcessInfo.processInfo.environment["MIXPANEL_TOKEN"] {
            return envToken
        }

        if let configToken = getValue(for: "MIXPANEL_TOKEN") {
            return configToken
        }

        // Main project token - replace with testing token for development
        return "cd4a90e61de738a65d45f68d22260ed2" // Main: Slay AI
        // Testing token: 0f3e2bf7cbcac849008b25c27ba7cf1b (SaaSDen Inc project)
    }

    // MARK: - Helper Methods
    private func getValue(for key: String) -> String? {
        // Try to read from Config.xcconfig
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "xcconfig"),
              let configContent = try? String(contentsOfFile: configPath) else {
            return nil
        }

        let lines = configContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("\(key) = ") {
                let value = trimmedLine.replacingOccurrences(of: "\(key) = ", with: "")
                return value.trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    // MARK: - Development Helpers
    func printConfiguration() {
        print("🔧 Configuration Status:")
        print("- Google Client ID: \(googleClientID.prefix(20))...\(googleClientID.suffix(20))")
        print("- Database API URL: \(databaseAPIBaseURL)")
        print("- Database API Timeout: \(databaseAPITimeout)s")
        print("- AppsFlyer Dev Key: ✅ Configured")
        print("- Apple App ID: \(appleAppID)")
        print("- Mixpanel Token: ✅ Configured")
        print("- Config file found: \(Bundle.main.path(forResource: "Config", ofType: "xcconfig") != nil)")
    }
}
