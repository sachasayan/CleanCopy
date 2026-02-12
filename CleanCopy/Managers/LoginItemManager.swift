import Foundation
import ServiceManagement
import AppKit

enum LoginItemManager {
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
            let errorAlert = NSAlert()
            errorAlert.messageText = "Failed to Add Login Item"
            errorAlert.informativeText = "Could not automatically add \(Constants.appName) as a login item."
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
        }
    }
}
