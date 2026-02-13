import Foundation
import AppKit
@testable import CleanCopy

class MockPasteboard: PasteboardService {
    var changeCount: Int = 0
    var types: [NSPasteboard.PasteboardType]?
    var strings: [NSPasteboard.PasteboardType: String] = [:]
    var lastWrittenObjects: [[NSPasteboardWriting]] = []
    
    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        return strings[type]
    }
    
    func clearContents() -> Int {
        changeCount += 1
        strings.removeAll()
        types = []
        return changeCount
    }
    
    func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        strings[type] = string
        if types == nil { types = [] }
        if !types!.contains(type) { types!.append(type) }
        changeCount += 1
        return true
    }
    
    func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool {
        lastWrittenObjects.append(objects)
        changeCount += 1
        
        // Simulate string extraction if it's an attributed string
        for object in objects {
            if let attributed = object as? NSAttributedString {
                strings[.string] = attributed.string
                if types == nil { types = [] }
                types?.append(.string)
            }
        }
        return true
    }
    
    func incrementChangeCount() {
        changeCount += 1
    }
}

class MockNetworkService: NetworkService {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error = mockError {
            throw error
        }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}
