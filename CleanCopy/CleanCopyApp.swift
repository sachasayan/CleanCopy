import SwiftUI
import AppKit
import Combine
import UserNotifications
import ServiceManagement
import os

// MARK: - App Entry Point

@main
struct CleanCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var clipboardManager = ClipboardManager()

    var body: some Scene {
        MenuBarExtra(Constants.appName, systemImage: "link.circle") {
            MainMenuView(clipboardManager: clipboardManager)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Models

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    
    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Core Components

/// AppDelegate handles application lifecycle and system integration initialization.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationManager.shared.requestAuthorization()
        DispatchQueue.main.async {
            LoginItemManager.promptIfNeeded()
        }
    }
}

/// Manages clipboard interactions, polling, and coordination of the conversion process.
class ClipboardManager: NSObject, ObservableObject {
    @Published var isAutoConvertEnabled: Bool = true
    @Published var history: [ClipboardItem] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    
    override init() {
        super.init()
        if isAutoConvertEnabled {
            startMonitoring()
        }
    }
    
    func startMonitoring() {
        guard isAutoConvertEnabled else { return }
        Logger.clipboard.info("Starting clipboard monitoring...")
        stopMonitoring()
        lastChangeCount = NSPasteboard.general.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: Constants.Intervals.clipboardPolling, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopMonitoring() {
        Logger.clipboard.info("Stopping clipboard monitoring.")
        timer?.invalidate()
        timer = nil
    }
    
    func toggleAutoConvert() {
        isAutoConvertEnabled.toggle()
        if isAutoConvertEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }
    
    private func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        // Skip if clipboard contains rich text to avoid self-looping
        if let types = NSPasteboard.general.types, types.contains(where: { $0 == .rtf || $0 == .rtfd }) {
            return
        }
        
        if let content = NSPasteboard.general.string(forType: .string) {
            updateHistory(with: content)
        }
        
        processClipboardContent()
    }
    
    private func updateHistory(with content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        // Prevent immediate duplicates
        if let first = history.first, first.content == trimmedContent {
            return
        }
        
        let newItem = ClipboardItem(content: trimmedContent)
        history.insert(newItem, at: 0)
        
        if history.count > Constants.historyMaxItems {
            history.removeLast()
        }
    }
    
    func copyToClipboard(_ content: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
        self.lastChangeCount = pb.changeCount
        Logger.clipboard.info("Copied item from history to clipboard.")
    }
    
    func clearHistory() {
        history.removeAll()
        Logger.clipboard.info("History cleared.")
    }
    
    func deleteHistoryItem(_ item: ClipboardItem) {
        history.removeAll(where: { $0.id == item.id })
    }
    
    func processClipboardContent() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedString), url.scheme != nil else { return }
        
        Logger.clipboard.info("Processing URL: \(url.absoluteString, privacy: .public)")
        
        Task {
            do {
                let title = try await TitleFetcher.fetchTitle(for: url)
                await createRichTextLink(url: url, title: title)
            } catch {
                Logger.clipboard.error("Failed to process URL: \(error.localizedDescription, privacy: .public)")
                await handleProcessingError(error, for: url)
            }
        }
    }
    
    @MainActor
    private func createRichTextLink(url: URL, title: String, notifySuccess: Bool = true) {
        let attributedString = NSMutableAttributedString(string: title)
        attributedString.addAttribute(.link, value: url.absoluteString, range: NSRange(location: 0, length: title.utf16.count))
        
        let pb = NSPasteboard.general
        pb.clearContents()
        let didWrite = pb.writeObjects([attributedString])
        
        if didWrite {
            self.lastChangeCount = pb.changeCount
            Logger.clipboard.info("Clipboard updated with rich text link.")
            if notifySuccess {
                NotificationManager.shared.sendSuccess(title: title)
            }
        }
    }
    
    @MainActor
    private func handleProcessingError(_ error: Error, for url: URL) {
        if self.lastChangeCount == NSPasteboard.general.changeCount,
           let currentString = NSPasteboard.general.string(forType: .string),
           currentString.trimmingCharacters(in: .whitespacesAndNewlines) == url.absoluteString {
            createRichTextLink(url: url, title: url.absoluteString, notifySuccess: false)
        }
        NotificationManager.shared.sendWarning(message: "Could not fetch page title (\(error.localizedDescription)). Using URL as link text.")
    }
    
    func showAbout() {
        let alert = NSAlert()
        alert.messageText = Constants.appName
        alert.informativeText = "Version 1.0\nCopyright © 2025 Interim Solutions. All rights reserved."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Views

struct MainMenuView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Controls
            HStack(spacing: 16) {
                Button(action: {
                    clipboardManager.processClipboardContent()
                }) {
                    Label("Convert URL", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("Auto")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Toggle("Auto Convert", isOn: $clipboardManager.isAutoConvertEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                }
                .help("Toggle automatic URL conversion")
                
                Menu {
                    Button("About") {
                        clipboardManager.showAbout()
                    }
                    Divider()
                    Button("Quit") {
                        clipboardManager.stopMonitoring()
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // History Section
            HistoryView(clipboardManager: clipboardManager)
        }
        .frame(width: 350, height: 450)
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct HistoryView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clipboard History")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if !clipboardManager.history.isEmpty {
                    Button("Clear") {
                        clipboardManager.clearHistory()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
            
            Divider()

            if clipboardManager.history.isEmpty {
                VStack {
                    Image(systemName: "clipboard")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    Text("Empty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(clipboardManager.history) { item in
                        HistoryItemRow(item: item, onCopy: {
                            clipboardManager.copyToClipboard(item.content)
                        }, onDelete: {
                            clipboardManager.deleteHistoryItem(item)
                        })
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct HistoryItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content)
                    .lineLimit(1)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text(item.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 10) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Services

/// Encapsulates the logic for fetching and parsing web page titles.
enum TitleFetcher {
    static func fetchTitle(for url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = Constants.Intervals.networkTimeout
        Logger.network.info("Fetching title for: \(url.absoluteString, privacy: .public)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return url.host ?? url.absoluteString
        }
        
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return url.host ?? url.absoluteString
        }
        
        return parseTitle(from: html, fallback: url.host ?? url.absoluteString)
    }
    
    private static func parseTitle(from html: String, fallback: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: Constants.Regex.titlePattern, options: .caseInsensitive)
            let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: nsRange),
               match.numberOfRanges > 1,
               let titleRange = Range(match.range(at: 1), in: html) {
                let title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                return title.isEmpty ? fallback : title
            }
        } catch {
            Logger.network.error("Regex error: \(error.localizedDescription, privacy: .public)")
        }
        return fallback
    }
}

// MARK: - Utilities

/// Centralizes notification logic and permission handling.
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() { super.init(); UNUserNotificationCenter.current().delegate = self }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error { Logger.system.error("Notification permission error: \(error.localizedDescription)") }
            DispatchQueue.main.async { self.checkStatusAndPrompt() }
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
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") { NSWorkspace.shared.open(url) }
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

/// Centralizes logic for registering the app as a login item.
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
        if alert.runModal() == .alertFirstButtonReturn { register() }
    }
    
    static func register() {
        do { try SMAppService.mainApp.register() }
        catch {
            Logger.system.error("Failed to register as login item: \(error.localizedDescription)")
            let errorAlert = NSAlert()
            errorAlert.messageText = "Failed to Add Login Item"
            errorAlert.informativeText = "Could not automatically add \(Constants.appName) as a login item."
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
        }
    }
}

// MARK: - Constants & Logger

enum Constants {
    static let appName = "CleanCopy"
    enum Keys {
        static let loginItemPromptShown = "loginItemPromptShown"
        static let notificationDisabledPromptShown = "notificationDisabledPromptShown"
    }
    enum Intervals {
        static let clipboardPolling: TimeInterval = 1.0
        static let networkTimeout: TimeInterval = 10.0
    }
    static let historyMaxItems = 50
    enum Regex { static let titlePattern = "<title[^>]*>(.*?)</title>" }
    enum Display { static let maxTitleLengthNotification = 50 }
}

enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sachasayan.CleanCopy"
    static let app = os.Logger(subsystem: subsystem, category: "App")
    static let clipboard = os.Logger(subsystem: subsystem, category: "Clipboard")
    static let network = os.Logger(subsystem: subsystem, category: "Network")
    static let system = os.Logger(subsystem: subsystem, category: "System")
}
