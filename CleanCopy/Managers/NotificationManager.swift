import Foundation
import UserNotifications
import AppKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                Logger.system.error("Notification permission error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.checkStatusAndPrompt()
            }
        }
    }
    
    func checkStatusAndPrompt() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                guard settings.authorizationStatus == .denied else { return }
                let alreadyPrompted = UserDefaults.standard.bool(forKey: Constants.Keys.notificationDisabledPromptShown)
                guard !alreadyPrompted else { return }
                
                let alert = NSAlert()
                alert.messageText = "Enable Notifications for \(Constants.appName)?"
                alert.informativeText = "\(Constants.appName) uses notifications to confirm when a link has been successfully copied and to report errors."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                alert.alertStyle = .informational
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
                UserDefaults.standard.set(true, forKey: Constants.Keys.notificationDisabledPromptShown)
            }
        }
    }
    
    func sendSuccess(title: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(Constants.appName) - Success"
        let displayTitle = title.count > Constants.Display.maxTitleLengthNotification ? "\(title.prefix(47))..." : title
        content.body = "Clipboard updated with link: \(displayTitle)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendWarning(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(Constants.appName) - Warning"
        content.body = message
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
