import Foundation
import AppKit

/// Protocol to abstract NSPasteboard for testability
protocol PasteboardService {
    var changeCount: Int { get }
    var types: [NSPasteboard.PasteboardType]? { get }
    func string(forType type: NSPasteboard.PasteboardType) -> String?
    func clearContents() -> Int
    func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool
    func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool
}

extension NSPasteboard: PasteboardService {}

/// Protocol to abstract URLSession for testability
protocol NetworkService {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkService {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await self.data(for: request, delegate: nil)
    }
}
