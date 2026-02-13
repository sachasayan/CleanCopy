import Foundation
import AppKit
import Combine
import os

@MainActor
class ClipboardManager: NSObject, ObservableObject {
    @Published var history: [ClipboardItem] = []
    
    private let pasteboard: PasteboardService
    private let titleFetcher: TitleFetcher
    private var timer: Timer?
    private var lastChangeCount: Int
    
    // State for 'double-copy' trigger
    private var pendingContent: String?
    private var consecutiveCopyCount: Int = 0
    
    init(pasteboard: PasteboardService = NSPasteboard.general, titleFetcher: TitleFetcher = .shared) {
        self.pasteboard = pasteboard
        self.titleFetcher = titleFetcher
        self.lastChangeCount = pasteboard.changeCount
        super.init()
        startMonitoring()
    }
    
    func startMonitoring() {
        Logger.clipboard.info("Starting clipboard monitoring...")
        stopMonitoring()
        lastChangeCount = pasteboard.changeCount
        
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
    
    internal func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount
        let delta = currentChangeCount - lastChangeCount
        guard delta > 0 else { return }
        lastChangeCount = currentChangeCount
        
        // Focus only on items with a string representation
        guard let content = pasteboard.string(forType: .string) else {
            // Reset state if non-string content is copied
            pendingContent = nil
            consecutiveCopyCount = 0
            return
        }
        
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if trimmed == pendingContent {
            consecutiveCopyCount += delta
        } else {
            pendingContent = trimmed
            consecutiveCopyCount = 1
        }
        
        // Determine type for history
        let type: ContentType
        if pasteboard.types?.contains(.rtf) == true || pasteboard.types?.contains(.rtfd) == true {
            type = .richText
        } else if let url = URL(string: trimmed), url.scheme != nil {
            type = .url
            // Trigger conversion ONLY if consecutive count >= 2
            if consecutiveCopyCount >= 2 {
                processClipboardContent()
            }
        } else {
            type = .text
        }
        
        updateHistory(with: trimmed, type: type)
    }
    
    internal func updateHistory(with content: String, type: ContentType, isCleanCopyResult: Bool = false) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualType = isCleanCopyResult ? .convertedLink : type
        
        // Simple duplicate prevention
        if let first = history.first, first.content == trimmedContent, first.type == actualType {
            return
        }
        
        let newItem = ClipboardItem(content: trimmedContent, type: actualType)
        
        self.history.insert(newItem, at: 0)
        if self.history.count > Constants.historyMaxItems {
            self.history.removeLast()
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        _ = pasteboard.clearContents()
        
        // If it's a file or image we just stored a placeholder, so we can't easily re-copy the actual data
        // For this version, we focus on re-copying text/URLs/RichText strings
        pasteboard.setString(item.content, forType: .string)
        self.lastChangeCount = pasteboard.changeCount
        Logger.clipboard.info("Copied item from history to clipboard: \(item.type.rawValue)")
    }
    
    func clearHistory() {
        history.removeAll()
        Logger.clipboard.info("History cleared.")
    }
    
    func deleteHistoryItem(_ item: ClipboardItem) {
        history.removeAll(where: { $0.id == item.id })
    }
    
    func processClipboardContent() {
        guard let clipboardString = pasteboard.string(forType: .string) else { return }
        let trimmedString = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedString), url.scheme != nil else { return }
        
        Logger.clipboard.info("Processing URL: \(url.absoluteString, privacy: .public)")
        
        Task {
            do {
                let title = try await titleFetcher.fetchTitle(for: url)
                await createRichTextLink(url: url, title: title)
            } catch {
                Logger.clipboard.error("Failed to process URL: \(error.localizedDescription, privacy: .public)")
                await handleProcessingError(error, for: url)
            }
        }
    }
    
    func convertHistoryItem(_ item: ClipboardItem) {
        guard item.type == .url, let url = URL(string: item.content) else { return }
        
        Task {
            do {
                let title = try await titleFetcher.fetchTitle(for: url)
                await createRichTextLink(url: url, title: title)
            } catch {
                await handleProcessingError(error, for: url)
            }
        }
    }
    
    @MainActor
    private func createRichTextLink(url: URL, title: String, notifySuccess: Bool = true) {
        let attributedString = NSMutableAttributedString(string: title)
        attributedString.addAttribute(.link, value: url.absoluteString, range: NSRange(location: 0, length: title.utf16.count))
        
        _ = pasteboard.clearContents()
        let didWrite = pasteboard.writeObjects([attributedString])
        
        if didWrite {
            self.lastChangeCount = pasteboard.changeCount
            // Reset trigger state after successful conversion
            self.pendingContent = nil
            self.consecutiveCopyCount = 0
            
            Logger.clipboard.info("Clipboard updated with rich text link.")
            
            // Add to history as a conversion result
            updateHistory(with: title, type: .convertedLink, isCleanCopyResult: true)
            
            if notifySuccess {
                NotificationManager.shared.sendSuccess(title: title)
            }
        }
    }
    
    @MainActor
    private func handleProcessingError(_ error: Error, for url: URL) {
        if self.lastChangeCount == pasteboard.changeCount,
           let currentString = pasteboard.string(forType: .string),
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

    deinit {
        // Since stopMonitoring accesses @MainActor, we should ideally stop it before deinit
        // But for cleanup, we can at least invalidate the timer
        timer?.invalidate()
    }
}
