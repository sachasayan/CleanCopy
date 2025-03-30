import AppKit
import SwiftUI
// Removed: import Cocoa - Redundant as AppKit includes Cocoa
import UserNotifications
import ServiceManagement // Import the ServiceManagement framework

/// AppDelegate handles application lifecycle events, specifically setting the app policy.
class AppDelegate: NSObject, NSApplicationDelegate {

    let loginItemPromptShownKey = "loginItemPromptShown" // UserDefaults key
    // Removed moveToApplicationsPromptShownKey

    /// Sets the application's activation policy to `.accessory` upon launch,
    /// making it a background/menu bar application without a Dock icon or main window by default.
    /// Also prompts the user to add the app as a login item on first launch.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Request notification permissions and set delegate
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }

        // Prompt user to add as login item on first launch
        // Call directly on main thread
        DispatchQueue.main.async {
             self.promptForLoginItemIfNeeded()
        }
    }

    // --- Removed Move to Applications Logic ---


    // --- Login Item Logic ---

    /// Checks if the login item prompt has been shown before, and if not, shows it.
    private func promptForLoginItemIfNeeded() {
        let currentKeyValue = UserDefaults.standard.bool(forKey: loginItemPromptShownKey) // Get its boolean value

        guard !currentKeyValue else { // Check the boolean value directly
            // Already shown, do nothing
            return
        }

        UserDefaults.standard.set(true, forKey: loginItemPromptShownKey)

        let alert = NSAlert()
        alert.messageText = "Launch CleanCopy at Login?"
        alert.informativeText = "Would you like CleanCopy to start automatically when you log in?"
        alert.addButton(withTitle: "Yes, Launch at Login") // First button (default action)
        alert.addButton(withTitle: "No")                  // Second button
        alert.alertStyle = .informational

        let response = alert.runModal()

        if response == .alertFirstButtonReturn { // User clicked "Yes"
            self.registerAsLoginItem() // Use the updated method
        } else {
            // User chose not to add login item.
        }
    }

    /// Registers the application as a login item using SMAppService.mainApp.
    private func registerAsLoginItem() {
        // Get app name for alerts, default to "CleanCopy"
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "CleanCopy"

        do {
            // Use the simpler .mainApp service which relies on Info.plist
            try SMAppService.mainApp.register()
            // Optionally show a success confirmation alert
            // let successAlert = NSAlert()
            // successAlert.messageText = "Login Item Added"
            // successAlert.informativeText = "\(appName) will now start automatically at login."
            // successAlert.addButton(withTitle: "OK")
            // successAlert.runModal()
        } catch {
            // Show a more detailed error alert to the user
            let errorAlert = NSAlert()
            errorAlert.messageText = "Failed to Add Login Item"
            errorAlert.informativeText = "Could not automatically add \(appName) as a login item.\n\nError: \(error.localizedDescription)\n\nYou can add it manually via System Settings > General > Login Items."
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
        }
    }

    // Optional: Add code to unregister when the app quits or based on user preference
    // func applicationWillTerminate(_ notification: Notification) {
    //     let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "CleanCopy"
    //     do {
    //         try SMAppService.mainApp.unregister()
    //         print("Successfully unregistered \(appName) as a login item.")
    //     } catch {
    //         print("Failed to unregister \(appName) as a login item: \(error.localizedDescription)")
    //     }
    // }
}

/// Extension to handle User Notification Center delegate methods.
extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Ensures notifications are presented (banner, sound) even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound])
    }
}

/// The main application structure conforming to the SwiftUI App protocol.
@main
struct CleanCopyApp: App {
    /// Adapts the AppDelegate to be used within the SwiftUI app lifecycle.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// Manages clipboard interactions and related logic, observed for UI updates if needed (though not currently used for UI updates).
    @StateObject private var clipboardManager = ClipboardManager()

    /// Defines the app's scenes. Currently uses a MenuBarExtra for the UI.
    var body: some Scene {
        MenuBarExtra("CleanCopy", systemImage: "link.circle") {
            // Menu item to trigger the URL conversion process.
            Button("Convert URL") {
                clipboardManager.handleMenuClick()
            }
            // Menu item to show the About dialog.
            Button("About") {
                clipboardManager.showAbout()
            }
            Divider() // Separator in the menu.
            // Menu item to quit the application.
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

/// Manages clipboard interactions, fetching web page titles, and creating rich text links.
class ClipboardManager: NSObject, ObservableObject {
    // Removed: private var lastClipboardContent: String = "" - Was unused.

    override init() {
        super.init()
    }

    /// Fetches the HTML title for a given URL.
    /// - Parameters:
    ///   - url: The URL to fetch the title from.
    ///   - completion: A closure called with the result (either the title string or an error).
    private func fetchPageTitle(for url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10 // 10 second timeout

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                // Network or other URLSession error occurred.
                completion(.failure(error))
                return
            }

            guard let data = data,
                  // Attempt to decode using UTF-8 first, fall back to ISO Latin 1 if needed for broader compatibility.
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                // If data exists but cannot be decoded into a string, use host/URL as fallback title.
                completion(.success(url.host ?? url.absoluteString))
                return
            }

            // Regex to find title: case-insensitive, allows attributes in <title> tag, captures content.
            let regexPattern = "<title[^>]*>(.*?)</title>"
            do {
                let regex = try NSRegularExpression(pattern: regexPattern, options: .caseInsensitive)
                let nsRange = NSRange(html.startIndex..<html.endIndex, in: html) // Range of the entire HTML string.

                if let match = regex.firstMatch(in: html, options: [], range: nsRange),
                   match.numberOfRanges > 1, // Ensure the capture group (.*?) exists.
                   let titleRange = Range(match.range(at: 1), in: html) { // Get Swift Range of the first capture group.

                    let title = String(html[titleRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines) // Clean up whitespace.
                    // Use fallback title if the extracted title is empty after trimming.
                    completion(.success(title.isEmpty ? (url.host ?? url.absoluteString) : title))
                } else {
                    // No <title> tag found, use host/URL as fallback title.
                    completion(.success(url.host ?? url.absoluteString))
                }
            } catch {
                // Regex compilation error (unlikely with a fixed pattern, but handled defensively).
                print("Regex error extracting title: \(error)")
                completion(.success(url.host ?? url.absoluteString)) // Use fallback on regex error.
            }
        }
        task.resume() // Start the data task.
    }

    /// Handles errors during the title fetching process. Shows a notification and uses the URL as the link text.
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - url: The URL for which the fetch failed.
    private func handleError(_ error: Error, for url: URL) {
        DispatchQueue.main.async { // Ensure UI updates are on the main thread.
            // Create the link using the URL itself as the title as a fallback.
            self.createRichTextLink(url: url, title: url.absoluteString)

            // Prepare and show a user notification about the failure.
            let content = UNMutableNotificationContent()
            content.title = "CleanCopy - Warning"
            // Provide more specific error info in the notification body.
            content.body = "Could not fetch page title (\(error.localizedDescription)). Using URL as link text."

            let request = UNNotificationRequest(identifier: UUID().uuidString, // Unique ID for the notification.
                                              content: content,
                                              trigger: nil) // nil trigger means show immediately.

            UNUserNotificationCenter.current().add(request) // Add the notification request to the queue.
        }
    }

    /// Creates a rich text (NSAttributedString) link and writes it to the general pasteboard.
    /// - Parameters:
    ///   - url: The URL for the link.
    ///   - title: The display text for the link.
    private func createRichTextLink(url: URL, title: String) {
        DispatchQueue.main.async { // Ensure pasteboard interaction is on the main thread.
            let attributedString = NSMutableAttributedString(string: title)
            // Apply the link attribute to the entire range of the title string.
            // Use title.utf16.count for correct range calculation with complex characters/emoji.
            attributedString.addAttribute(.link, value: url.absoluteString, range: NSRange(location: 0, length: title.utf16.count))

            let pb = NSPasteboard.general // Get the general pasteboard.
            pb.clearContents() // Clear previous contents before writing.
            pb.writeObjects([attributedString]) // Write the attributed string object.
        }
    }


    /// Displays a standard macOS About dialog with app information.
    func showAbout() {
        let alert = NSAlert()
        alert.messageText = "CleanCopy"
        alert.informativeText = "Version 1.0\nCopyright © 2025 Interim Solutions. All rights reserved." // Includes version and copyright.
        alert.alertStyle = .informational // Standard informational style.
        alert.addButton(withTitle: "OK") // Standard OK button.
        alert.runModal() // Display the alert modally.
    }

    /// Handles the action when the "Convert URL" menu item is clicked.
    /// Reads the clipboard, validates if it's a URL, and initiates the title fetching process.
    func handleMenuClick() {
        // 1. Read string from the general pasteboard.
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return } // Exit if no string content.

        // 2. Trim whitespace and check if it's a valid URL with a scheme.
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedString),
              url.scheme != nil // Ensure it has a scheme (e.g., http, https).
        else {
            // Clipboard content is not a valid URL, optionally notify user or just return silently.
            print("Clipboard content is not a valid URL: \(trimmedString)")
            // Consider showing a notification here if desired.
            return
        }

        // Removed: lastClipboardContent = clipboardString - Was unused.

        // 3. Fetch title and update pasteboard asynchronously.
        fetchPageTitle(for: url) { [weak self] result in
            // Use weak self to avoid potential retain cycles in the completion handler.
            switch result {
            case .success(let title):
                // Ensure title is not empty before creating link; use URL as fallback if it is.
                let linkTitle = title.isEmpty ? url.absoluteString : title
                self?.createRichTextLink(url: url, title: linkTitle)
            case .failure(let error):
                // Handle the error (e.g., show notification, use fallback title).
                self?.handleError(error, for: url)
            }
        }
    }
}
