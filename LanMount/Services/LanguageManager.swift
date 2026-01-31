//
//  LanguageManager.swift
//  LanMount
//
//  Manages application language settings and localization
//

import Foundation
import SwiftUI

/// Supported languages in the application
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    
    var id: String { rawValue }
    
    /// Display name for the language
    var displayName: String {
        switch self {
        case .system:
            return NSLocalizedString("System Default", comment: "System language option")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
    
    /// Native display name (always in the target language)
    var nativeDisplayName: String {
        switch self {
        case .system:
            return NSLocalizedString("System Default", comment: "System language option")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

/// Manages application language settings
@MainActor
class LanguageManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LanguageManager()
    
    // MARK: - Published Properties
    
    /// Currently selected language
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguagePreference()
            applyLanguage()
        }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let languageKey = "AppLanguage"
    
    // MARK: - Initialization
    
    private init() {
        // Load saved language preference
        if let savedLanguage = userDefaults.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
        
        // Apply the language on initialization
        applyLanguage()
    }
    
    // MARK: - Public Methods
    
    /// Sets the application language
    /// - Parameter language: The language to set
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
    
    /// Gets the current effective language code
    /// - Returns: The language code (e.g., "en", "zh-Hans")
    func getCurrentLanguageCode() -> String {
        switch currentLanguage {
        case .system:
            return Locale.preferredLanguages.first ?? "en"
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
    
    // MARK: - Private Methods
    
    /// Saves the language preference to UserDefaults
    private func saveLanguagePreference() {
        userDefaults.set(currentLanguage.rawValue, forKey: languageKey)
    }
    
    /// Applies the selected language to the application
    private func applyLanguage() {
        let languageCode: String?
        
        switch currentLanguage {
        case .system:
            // Use system language
            languageCode = nil
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            languageCode = "en"
        case .simplifiedChinese:
            languageCode = "zh-Hans"
        }
        
        if let code = languageCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
        
        UserDefaults.standard.synchronize()
        
        // Post notification for language change
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the application language changes
    static let languageDidChange = Notification.Name("LanguageDidChange")
}

// MARK: - Environment Key

/// Environment key for accessing LanguageManager
private struct LanguageManagerKey: EnvironmentKey {
    static let defaultValue: LanguageManager = .shared
}

extension EnvironmentValues {
    var languageManager: LanguageManager {
        get { self[LanguageManagerKey.self] }
        set { self[LanguageManagerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects the LanguageManager into the environment
    func withLanguageManager() -> some View {
        self.environmentObject(LanguageManager.shared)
    }
}
