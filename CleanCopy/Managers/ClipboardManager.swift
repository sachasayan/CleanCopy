import Foundation
import AppKit
import Combine
import os

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
        let pb = NSPasteboard.general
        let currentChangeCount = pb.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        // Focus only on items with a string representation
        guard let content = pb.string(forType: .string) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Determine type based on properties
        if pb.types?.contains(.rtf) == true || pb.types?.contains(.rtfd) == true {
            updateHistory(with: trimmed, type: .richText)
        } else if let url = URL(string: trimmed), url.scheme != nil {
            updateHistory(with: trimmed, type: .url)
            if isAutoConvertEnabled {
                processClipboardContent()
            }
        } else {
            updateHistory(with: trimmed, type: .text)
        }
    }
    
    private func updateHistory(with content: String, type: ContentType, isCleanCopyResult: Bool = false) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualType = isCleanCopyResult ? .convertedLink : type
        
        // Simple duplicate prevention
        if let first = history.first, first.content == trimmedContent, first.type == actualType {
            return
        }
        
        let newItem = ClipboardItem(content: trimmedContent, type: actualType)
        
        DispatchQueue.main.async {
            self.history.insert(newItem, at: 0)
            if self.history.count > Constants.historyMaxItems {
                self.history.removeLast()
            }
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        
        // If it's a file or image we just stored a placeholder, so we can't easily re-copy the actual data
        // For this version, we focus on re-copying text/URLs/RichText strings
        pb.setString(item.content, forType: .string)
        self.lastChangeCount = pb.changeCount
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
    
    func convertHistoryItem(_ item: ClipboardItem) {
        guard item.type == .url, let url = URL(string: item.content) else { return }
        
        Task {
            do {
                let title = try await TitleFetcher.fetchTitle(for: url)
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
        
        let pb = NSPasteboard.general
        pb.clearContents()
        let didWrite = pb.writeObjects([attributedString])
        
        if didWrite {
            self.lastChangeCount = pb.changeCount
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
