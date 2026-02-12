import Testing
import Foundation
@testable import CleanCopy

@Suite("TitleFetcher Tests")
struct TitleFetcherTests {
    
    @Test("Successful title extraction")
    func testSuccessfulFetch() async throws {
        let mockNetwork = MockNetworkService()
        let html = "<html><head><title>CleanCopy Test Page</title></head></html>"
        mockNetwork.mockData = html.data(using: .utf8)
        mockNetwork.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let fetcher = TitleFetcher(network: mockNetwork)
        let title = try await fetcher.fetchTitle(for: URL(string: "https://example.com")!)
        
        #expect(title == "CleanCopy Test Page")
    }
    
    @Test("Fall back to host on 404")
    func test404Fallback() async throws {
        let mockNetwork = MockNetworkService()
        mockNetwork.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 404, httpVersion: nil, headerFields: nil)
        
        let fetcher = TitleFetcher(network: mockNetwork)
        let title = try await fetcher.fetchTitle(for: URL(string: "https://example.com")!)
        
        #expect(title == "example.com")
    }
    
    @Test("Handle missing title tag")
    func testMissingTitle() async throws {
        let mockNetwork = MockNetworkService()
        let html = "<html><body>No title here</body></html>"
        mockNetwork.mockData = html.data(using: .utf8)
        mockNetwork.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com/page")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let fetcher = TitleFetcher(network: mockNetwork)
        let title = try await fetcher.fetchTitle(for: URL(string: "https://example.com/page")!)
        
        #expect(title == "example.com")
    }
}
