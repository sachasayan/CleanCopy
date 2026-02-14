import Foundation

enum Constants {
    static let appName = "CleanCopy"
    
    enum Keys {
        static let loginItemPromptShown = "loginItemPromptShown"
        static let notificationDisabledPromptShown = "notificationDisabledPromptShown"
        static let isOnboardingCompleted = "isOnboardingCompleted"
    }
    
    enum Intervals {
        static let clipboardPolling: TimeInterval = 0.25
        static let networkTimeout: TimeInterval = 10.0
    }
    
    static let historyMaxItems = 12
    
    enum Regex {
        static let titlePattern = "<title[^>]*>(.*?)</title>"
    }
    
    enum Display {
        static let maxTitleLengthNotification = 50
    }
}
