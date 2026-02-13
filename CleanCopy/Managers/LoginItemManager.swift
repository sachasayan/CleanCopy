import Foundation
import ServiceManagement
import AppKit

enum LoginItemManager {
    static var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    static func promptIfNeeded() {
        let alreadyPrompted = UserDefaults.standard.bool(forKey: Constants.Keys.loginItemPromptShown)
        guard !alreadyPrompted else { return }
        UserDefaults.standard.set(true, forKey: Constants.Keys.loginItemPromptShown)
        
        let alert = NSAlert()
        alert.messageText = "Launch \(Constants.appName) at Login?"
        alert.informativeText = "Would you like \(Constants.appName) to start automatically when you log in?"
        alert.addButton(withTitle: "Yes, Launch at Login")
        alert.addButton(withTitle: "No")
        if alert.runModal() == .alertFirstButtonReturn {
            register()
        }
    }
    
    static func register() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            Logger.system.error("Failed to register as login item: \(error.localizedDescription)")
            // If it's already registered, we might get an error depending on the exact state,
            // but usually register() is idempotent or handles it. 
            // However, we should be careful with UI alerts if this is called from a toggle.
        }
    }
    
    static func unregister() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            Logger.system.error("Failed to unregister as login item: \(error.localizedDescription)")
        }
    }
}
