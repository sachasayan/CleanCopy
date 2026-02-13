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
        manager.stopMonitoring()
        manager.clearHistory()
        
        // Simulate a copy
        mockPb.setString("Hello Test", forType: .string)
        
        // Trigger check manually
        manager.checkClipboard()
        
        #expect(manager.history.count == 1)
        #expect(manager.history.first?.content == "Hello Test")
        #expect(manager.history.first?.type == .text)
    }
    
    @Test("URL detection and processing (Double-Copy required)")
    func testURLDetection() async throws {
        let mockPb = MockPasteboard()
        let mockNetwork = MockNetworkService()
        mockNetwork.mockData = "<html><head><title>Test</title></head></html>".data(using: .utf8)
        mockNetwork.mockResponse = HTTPURLResponse(url: URL(string: "https://google.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let fetcher = TitleFetcher(network: mockNetwork)
        let manager = ClipboardManager(pasteboard: mockPb, titleFetcher: fetcher)
        manager.stopMonitoring()
        manager.clearHistory()
        
        // First copy
        mockPb.setString("https://google.com", forType: .string)
        manager.checkClipboard()
        #expect(manager.history.first?.type == .url)
        #expect(manager.history.count == 1)
        
        // Second copy of SAME URL
        mockPb.incrementChangeCount()
        manager.checkClipboard()
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(manager.history.contains(where: { $0.type == .convertedLink }))
        #expect(manager.history.first(where: { $0.type == .convertedLink })?.content == "Test")
    }

    @Test("Double-copy of same content (delta >= 2 on second copy)")
    func testDoubleCopySuccess() async throws {
        let mockPb = MockPasteboard()
        let mockNetwork = MockNetworkService()
        mockNetwork.mockData = "<html><head><title>Test</title></head></html>".data(using: .utf8)
        mockNetwork.mockResponse = HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let fetcher = TitleFetcher(network: mockNetwork)
        let manager = ClipboardManager(pasteboard: mockPb, titleFetcher: fetcher)
        manager.stopMonitoring()
        manager.clearHistory()
        
        // Initial copy (delta could be 2, but should only count as 1)
        mockPb.setString("https://apple.com", forType: .string)
        mockPb.incrementChangeCount() 
        manager.checkClipboard()
        #expect(!manager.history.contains(where: { $0.type == .convertedLink }))
        
        // Second copy (triggers conversion)
        mockPb.incrementChangeCount()
        manager.checkClipboard()
        
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(manager.history.contains(where: { $0.type == .convertedLink }))
    }

    @Test("Counter reset on different content")
    func testCounterReset() async throws {
        let mockPb = MockPasteboard()
        let mockNetwork = MockNetworkService()
        mockNetwork.mockData = "<html><head><title>Test</title></head></html>".data(using: .utf8)
        mockNetwork.mockResponse = HTTPURLResponse(url: URL(string: "https://url1.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let fetcher = TitleFetcher(network: mockNetwork)
        let manager = ClipboardManager(pasteboard: mockPb, titleFetcher: fetcher)
        manager.stopMonitoring()
        manager.clearHistory()
        
        // Copy URL1
        mockPb.setString("https://url1.com", forType: .string)
        manager.checkClipboard()
        
        // Copy URL2
        mockPb.setString("https://url2.com", forType: .string)
        manager.checkClipboard()
        
        // Copy URL1 again (not consecutive)
        mockPb.setString("https://url1.com", forType: .string)
        manager.checkClipboard()
        
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(!manager.history.contains(where: { $0.type == .convertedLink }))
        
        // Second copy of URL1
        mockPb.incrementChangeCount()
        manager.checkClipboard()
        
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(manager.history.contains(where: { $0.type == .convertedLink }))
    }
    
    @Test("Deduplication logic")
    func testDeduplication() {
        let mockPb = MockPasteboard()
        let manager = ClipboardManager(pasteboard: mockPb)
        manager.stopMonitoring()
        manager.clearHistory()
        
        manager.updateHistory(with: "Duplicate", type: .text)
        manager.updateHistory(with: "Duplicate", type: .text)
        
        #expect(manager.history.count == 1)
    }
    
    @Test("History capacity limit")
    func testHistoryLimit() {
        let mockPb = MockPasteboard()
        let manager = ClipboardManager(pasteboard: mockPb)
        manager.stopMonitoring()
        manager.clearHistory()
        
        for i in 1...60 {
            manager.updateHistory(with: "Item \(i)", type: .text)
        }
        
        #expect(manager.history.count == Constants.historyMaxItems)
        #expect(manager.history.first?.content == "Item 60")
    }
}
