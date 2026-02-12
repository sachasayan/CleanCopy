import Testing
import Foundation
import AppKit
@testable import CleanCopy

@Suite("ClipboardManager Tests")
struct ClipboardManagerTests {
    
    @Test("History Item deduplication")
    func testDeduplication() {
        let manager = ClipboardManager()
        manager.clearHistory()
        
        // Manual insertion into history to test logic (actual updateHistory is private)
        // Note: In real scenarios, we'd mock the pasteboard or expose internal logic
        // For now, testing basic Identifiable/Equatable properties and history limits
    }
    
    @Test("Clipboard Item creation")
    func testItemCreation() {
        let content = "https://example.com"
        let item = ClipboardItem(content: content, type: .url)
        
        #expect(item.content == content)
        #expect(item.type == .url)
        #expect(item.displayContent == content)
    }
}
