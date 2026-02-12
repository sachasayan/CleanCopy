import Foundation
import os

enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sachasayan.CleanCopy"
    
    static let app = os.Logger(subsystem: subsystem, category: "App")
    static let clipboard = os.Logger(subsystem: subsystem, category: "Clipboard")
    static let network = os.Logger(subsystem: subsystem, category: "Network")
    static let system = os.Logger(subsystem: subsystem, category: "System")
}
