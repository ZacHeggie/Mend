import Foundation
import SwiftUI

/// Class to manage developer-specific settings in the app
class DeveloperSettings: ObservableObject {
    /// Shared singleton instance
    static let shared = DeveloperSettings()
    
    // Keys for UserDefaults
    private let kUseRandomVariation = "useRandomVariation"
    private let kIsDeveloperMode = "isDeveloperMode"
    private let kShowAllActivityRecommendations = "showAllActivityRecommendations"
    
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
    
    /// Flag to determine if all activity recommendation cards should be shown for testing
    @Published var showAllActivityRecommendations: Bool {
        didSet {
            UserDefaults.standard.set(showAllActivityRecommendations, forKey: kShowAllActivityRecommendations)
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
        
        // Initialize show all activity recommendations setting
        let savedShowAllRecommendations = UserDefaults.standard.bool(forKey: kShowAllActivityRecommendations)
        self.showAllActivityRecommendations = savedShowAllRecommendations
    }
    
    /// Reset all developer settings to default values
    func resetToDefaults() {
        useRandomVariation = false
        isDeveloperMode = false
        showAllActivityRecommendations = false
    }
} 
