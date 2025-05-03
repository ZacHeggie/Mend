import Foundation
import SwiftUI

/// Class to manage developer-specific settings in the app
class DeveloperSettings: ObservableObject {
    /// Shared singleton instance
    static let shared = DeveloperSettings()
    
    // Keys for UserDefaults
    private let kUseRandomVariation = "useRandomVariation"
    private let kIsDeveloperMode = "isDeveloperMode"
    
    /// Flag to determine if random variations should be used for recovery scores
    @Published var useRandomVariation: Bool {
        didSet {
            UserDefaults.standard.set(useRandomVariation, forKey: kUseRandomVariation)
        }
    }
    
    /// Flag to determine if the app is in developer mode
    @Published var isDeveloperMode: Bool {
        didSet {
            UserDefaults.standard.set(isDeveloperMode, forKey: kIsDeveloperMode)
        }
    }
    
    private init() {
        // Initialize with default values if not already set
        let savedRandomVariation = UserDefaults.standard.bool(forKey: kUseRandomVariation)
        self.useRandomVariation = savedRandomVariation
        
        #if DEBUG
        let defaultDevMode = false
        #else
        let defaultDevMode = false
        #endif
        
        let savedDevMode = UserDefaults.standard.object(forKey: kIsDeveloperMode) != nil ? 
            UserDefaults.standard.bool(forKey: kIsDeveloperMode) : defaultDevMode
        
        self.isDeveloperMode = savedDevMode
    }
    
    /// Reset all developer settings to default values
    func resetToDefaults() {
        useRandomVariation = false
        
        #if DEBUG
        isDeveloperMode = false
        #else
        isDeveloperMode = false
        #endif
    }
} 
