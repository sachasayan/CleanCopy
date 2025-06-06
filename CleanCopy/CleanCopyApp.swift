import AppKit
import SwiftUI
// Removed: import Cocoa - Redundant as AppKit includes Cocoa
import UserNotifications
import ServiceManagement // Import the ServiceManagement framework
import Combine // Import Combine for Timer

/// AppDelegate handles application lifecycle events, specifically setting the app policy.
class AppDelegate: NSObject, NSApplicationDelegate {

    let loginItemPromptShownKey = "loginItemPromptShown" // UserDefaults key
    let notificationDisabledPromptShownKey = "notificationDisabledPromptShown" // New key

    /// Sets the application's activation policy to `.accessory` upon launch,
    /// making it a background/menu bar application without a Dock icon or main window by default.
    /// Also prompts the user to add the app as a login item on first launch.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Request notification permissions and set delegate
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async { // Ensure subsequent checks run on main thread if needed
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
                // Check settings and prompt if denied and not prompted before
                self.checkNotificationSettingsAndPromptIfNeeded()
            }
        }

        // Prompt user to add as login item on first launch
        // Call directly on main thread
        DispatchQueue.main.async {
             self.promptForLoginItemIfNeeded()
        }
    }

    // --- Check Notification Settings and Prompt ---
    /// Checks current notification settings and prompts the user if notifications are denied.
    private func checkNotificationSettingsAndPromptIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            // Check status on the main thread for UI updates
            DispatchQueue.main.async {
                guard settings.authorizationStatus == .denied else {
                    // Notifications are allowed or not yet determined, do nothing.
                    return
                }

                // Notifications are denied. Check if we've already prompted the user.
                let alreadyPrompted = UserDefaults.standard.bool(forKey: self.notificationDisabledPromptShownKey)
                guard !alreadyPrompted else {
                    // Already prompted, don't show the alert again.
                    return
                }

                // Show the alert guiding the user to settings.
                let alert = NSAlert()
                alert.messageText = "Enable Notifications for CleanCopy?"
                alert.informativeText = "CleanCopy uses notifications to confirm when a link has been successfully copied and to report errors.\n\nTo enable them, please go to System Settings > Notifications > CleanCopy and turn on 'Allow Notifications'."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                alert.alertStyle = .informational

                let response = alert.runModal()

                if response == .alertFirstButtonReturn { // User clicked "Open System Settings"
                    // Attempt to open the Notifications settings pane.
                    // Note: This specific deep link might change in future macOS versions.
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                         NSWorkspace.shared.open(url)
                    }
                }

                // Mark that we've shown the prompt.
                UserDefaults.standard.set(true, forKey: self.notificationDisabledPromptShownKey)
            }
        }
    }
    // --- End Check Notification Settings ---


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
        } catch {
            // Show a more detailed error alert to the user
            let errorAlert = NSAlert()
            errorAlert.messageText = "Failed to Add Login Item"
            errorAlert.informativeText = "Could not automatically add \(appName) as a login item.\n\nError: \(error.localizedDescription)\n\nYou can add it manually via System Settings > General > Login Items."
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
        }
    }
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
    /// Manages clipboard interactions and related logic, observed for UI updates.
    @StateObject private var clipboardManager = ClipboardManager()

    /// Defines the app's scenes. Currently uses a MenuBarExtra for the UI.
    var body: some Scene {
        MenuBarExtra("CleanCopy", systemImage: "link.circle") {
            // Menu item to trigger the URL conversion process manually.
            Button("Convert URL") {
                clipboardManager.processClipboardContent() // Use refactored method
            }
            // Menu item to toggle automatic conversion.
            Button {
                clipboardManager.toggleAutoConvert()
            } label: {
                // Use HStack for explicit layout control
                HStack {
                    // Conditionally show checkmark
                    if clipboardManager.isAutoConvertEnabled {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor) // Optional: Match system accent color
                    } else {
                        // Optional: Add placeholder space to maintain alignment when checkmark is hidden
                        // Image(systemName: "checkmark").hidden()
                        // Or use fixed width spacer:
                         Spacer().frame(width: 14) // Adjust width as needed
                    }
                    Text("Auto Convert")
                }
            }

            Divider() // Separator

            // Menu item to show the About dialog.
            Button("About") {
                clipboardManager.showAbout()
            }
            // Menu item to quit the application.
            Button("Quit") {
                clipboardManager.stopMonitoring() // Stop timer before quitting
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

/// Manages clipboard interactions, fetching web page titles, and creating rich text links.
class ClipboardManager: NSObject, ObservableObject {

    // --- State for Auto Convert ---
    // Default to true
    @Published var isAutoConvertEnabled: Bool = true
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let pollingInterval: TimeInterval = 1.0 // 1 second
    // --- End State ---

    override init() {
        super.init()
        // Initialize lastChangeCount on creation
        lastChangeCount = NSPasteboard.general.changeCount
        // Start monitoring immediately if default is enabled
        if isAutoConvertEnabled {
            startMonitoring()
        }
    }

    // --- Clipboard Monitoring ---

    /// Starts the timer to monitor clipboard changes.
    private func startMonitoring() {
        // Ensure this runs only if enabled
        guard isAutoConvertEnabled else { return }
        print("Starting clipboard monitoring...")
        stopMonitoring() // Ensure any existing timer is stopped first
        lastChangeCount = NSPasteboard.general.changeCount // Reset change count
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        // Ensure the timer runs on the main run loop for UI updates if needed, though checkClipboard is mostly background safe
         RunLoop.main.add(timer!, forMode: .common)
    }

    /// Stops the clipboard monitoring timer.
    func stopMonitoring() {
        print("Stopping clipboard monitoring.")
        timer?.invalidate()
        timer = nil
    }

    /// Checks the clipboard for changes and triggers processing if a new plain text URL is detected.
    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else {
            // No change detected
            return
        }

        // Update last change count *before* processing to avoid re-processing the same change
        lastChangeCount = currentChangeCount
        print("Clipboard change detected (Count: \(currentChangeCount)). Checking content...")

        // Check if the clipboard contains RTF/RTFD to avoid processing our own output or other rich text.
        if let types = NSPasteboard.general.types, types.contains(where: { $0 == .rtf || $0 == .rtfd }) {
            print("Clipboard contains RTF(D), ignoring.")
            return
        }

        // If it's likely plain text, process it.
        processClipboardContent()
    }

    /// Toggles the automatic clipboard monitoring feature on or off.
    func toggleAutoConvert() {
        isAutoConvertEnabled.toggle()
        if isAutoConvertEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    // --- Core Conversion Logic ---

    /// Reads the clipboard, validates if it's a URL, and initiates the title fetching process.
    /// This is the core logic triggered either manually or by the timer.
    func processClipboardContent() {
        // 1. Read string from the general pasteboard.
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            print("No string content found on clipboard.")
            return // Exit if no string content.
        }

        // 2. Trim whitespace and check if it's a valid URL with a scheme.
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedString),
              url.scheme != nil // Ensure it has a scheme (e.g., http, https).
        else {
            // Clipboard content is not a valid URL
            print("Clipboard content is not a valid URL: \(trimmedString)")
            return
        }

        print("Valid URL found: \(url.absoluteString). Fetching title...")
        // 3. Fetch title and update pasteboard asynchronously.
        fetchPageTitle(for: url) { [weak self] result in
            // Use weak self to avoid potential retain cycles in the completion handler.
            switch result {
            case .success(let title):
                // Ensure title is not empty before creating link; use URL as fallback if it is.
                let linkTitle = title.isEmpty ? url.absoluteString : title
                print("Title fetched successfully: \(linkTitle). Creating link...")
                // Call createRichTextLink with default notifySuccess: true
                self?.createRichTextLink(url: url, title: linkTitle)
            case .failure(let error):
                // Handle the error (e.g., show notification, use fallback title).
                print("Error fetching title: \(error.localizedDescription). Handling error...")
                self?.handleError(error, for: url)
            }
        }
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
            // Important: Check if the clipboard *still* contains the original URL before overwriting on error.
            // This prevents overwriting if the user copied something else while the fetch was failing.
            let currentChangeCount = NSPasteboard.general.changeCount
            if self.lastChangeCount == currentChangeCount, // Check if clipboard changed *again*
               let currentClipboardString = NSPasteboard.general.string(forType: .string),
               currentClipboardString.trimmingCharacters(in: .whitespacesAndNewlines) == url.absoluteString {
                 print("Handling error by writing fallback link to clipboard.")
                 self.createRichTextLink(url: url, title: url.absoluteString, notifySuccess: false) // Don't notify success on error fallback
            } else {
                print("Clipboard changed during error handling or doesn't match original URL. Skipping fallback write.")
            }


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

    /// Creates a rich text (NSAttributedString) link and writes it to the general pasteboard. Optionally sends a success notification.
    /// - Parameters:
    ///   - url: The URL for the link.
    ///   - title: The display text for the link.
    ///   - notifySuccess: Whether to send a success notification. Defaults to true.
    private func createRichTextLink(url: URL, title: String, notifySuccess: Bool = true) {
        // Ensure pasteboard interaction and notification scheduling are on the main thread.
        DispatchQueue.main.async {
            let attributedString = NSMutableAttributedString(string: title)
            // Apply the link attribute to the entire range of the title string.
            // Use title.utf16.count for correct range calculation with complex characters/emoji.
            attributedString.addAttribute(.link, value: url.absoluteString, range: NSRange(location: 0, length: title.utf16.count))

            let pb = NSPasteboard.general // Get the general pasteboard.
            pb.clearContents() // Clear previous contents before writing.
            // Write the attributed string object. This implicitly declares the .rtf type.
            let didWrite = pb.writeObjects([attributedString])

            if didWrite {
                 // Update the change count *after* successfully writing to the pasteboard
                 self.lastChangeCount = pb.changeCount
                 print("Successfully wrote rich text link to clipboard. New change count: \(self.lastChangeCount)")

                 // --- Add Success Notification ---
                 if notifySuccess {
                     let content = UNMutableNotificationContent()
                     content.title = "CleanCopy - Success"
                     // Truncate long titles in notification for brevity
                     let displayTitle = title.count > 50 ? "\(title.prefix(47))..." : title
                     content.body = "Clipboard updated with link: \(displayTitle)"
                     content.sound = UNNotificationSound.default // Optional: Add default sound

                     let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                       content: content,
                                                       trigger: nil) // Show immediately

                     UNUserNotificationCenter.current().add(request)
                 }
                 // --- End Success Notification ---
            } else {
                print("Error: Failed to write rich text link to clipboard.")
                // Optionally show an error notification here as well
            }
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

    // Removed original handleMenuClick as its logic is now in processClipboardContent
}
