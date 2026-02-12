import Testing
import Foundation
import AppKit
@testable import CleanCopy

@Suite("ClipboardManager Tests")
@MainActor
struct ClipboardManagerTests {
    
    @Test("History updates on clipboard change")
    func testClipboardPolling() async throws {
        let mockPb = MockPasteboard()
        let manager = ClipboardManager(pasteboard: mockPb)
        manager.clearHistory()
        
        // Simulate a copy
        mockPb.setString("Hello Test", forType: .string)
        
        // Trigger check manually
        manager.checkClipboard()
        
        #expect(manager.history.count == 1)
        #expect(manager.history.first?.content == "Hello Test")
        #expect(manager.history.first?.type == .text)
    }
    
    @Test("URL detection and processing")
    func testURLDetection() async throws {
        let mockPb = MockPasteboard()
        let manager = ClipboardManager(pasteboard: mockPb)
        manager.clearHistory()
        manager.isAutoConvertEnabled = false // Disable auto-convert for deterministic test
        
        mockPb.setString("https://google.com", forType: .string)
        manager.checkClipboard()
        
        #expect(manager.history.first?.type == .url)
    }
    
    @Test("Deduplication logic")
    func testDeduplication() {
        let mockPb = MockPasteboard()
        let manager = ClipboardManager(pasteboard: mockPb)
        manager.clearHistory()
        
        manager.updateHistory(with: "Duplicate", type: .text)
        manager.updateHistory(with: "Duplicate", type: .text)
        
        #expect(manager.history.count == 1)
    }
    
    @Test("History capacity limit")
    func testHistoryLimit() {
        let mockPb = MockPasteboard()
        let manager = ClipboardManager(pasteboard: mockPb)
        manager.clearHistory()
        
        for i in 1...60 {
            manager.updateHistory(with: "Item \(i)", type: .text)
        }
        
        #expect(manager.history.count == Constants.historyMaxItems)
        #expect(manager.history.first?.content == "Item 60")
    }
}
