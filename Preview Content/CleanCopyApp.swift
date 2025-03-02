import AppKit
import SwiftUI
import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound])
    }
}

@main
struct CleanCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var clipboardManager = ClipboardManager()
    
    var body: some Scene {
        MenuBarExtra("CleanCopy", systemImage: "link.circle") {
            Button("Convert URL") {
                clipboardManager.handleMenuClick()
            }
            Button("About") {
                clipboardManager.showAbout()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

class ClipboardManager: NSObject, ObservableObject {
    private var lastClipboardContent: String = ""
    
    override init() {
        super.init()
    }

    private func fetchPageTitle(for url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                completion(.success(url.host ?? url.absoluteString))
                return
            }
            
            if let titleRange = html.range(of: "<title>"),
               let titleEndRange = html.range(of: "</title>") {
                let title = html[titleRange.upperBound..<titleEndRange.lowerBound]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                completion(.success(title))
            } else {
                completion(.success(url.host ?? url.absoluteString))
            }
        }
        task.resume()
    }
    
    private func handleError(_ error: Error, for url: URL) {
        DispatchQueue.main.async {
            self.createRichTextLink(url: url, title: url.absoluteString)
            
            let content = UNMutableNotificationContent()
            content.title = "CleanCopy - Warning"
            content.body = "Could not fetch page title. Using URL as link text."
            
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                              content: content,
                                              trigger: nil)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func createRichTextLink(url: URL, title: String) {
        DispatchQueue.main.async {
            let attributedString = NSMutableAttributedString(string: title)
            attributedString.addAttribute(.link, value: url.absoluteString, range: NSRange(location: 0, length: title.count))
            
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([attributedString])
            
        }
    }
    

    
    func showAbout() {
        let alert = NSAlert()
        alert.messageText = "CleanCopy"
        alert.informativeText = "Version 1.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func handleMenuClick() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {return}
                
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
              guard let url = URL(string: trimmedString),
                    url.scheme != nil
        else {
            return
        }
        

        lastClipboardContent = clipboardString
        
        fetchPageTitle(for: url) { [weak self] result in
            switch result {
            case .success(let title):
                self?.createRichTextLink(url: url, title: title)
            case .failure(let error):
                self?.handleError(error, for: url)
            }
        }
    }
}
