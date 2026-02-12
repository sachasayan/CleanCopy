import Testing
import Foundation
@testable import CleanCopy

@Suite("Constants Tests")
struct ConstantsTests {
    
    @Test("Title Regex Pattern")
    func testTitleRegex() {
        let html = "<html><head><title>Test Title</title></head></html>"
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let regex = try! NSRegularExpression(pattern: Constants.Regex.titlePattern, options: .caseInsensitive)
        
        let match = regex.firstMatch(in: html, options: [], range: range)
        #expect(match != nil)
        
        if let match = match, match.numberOfRanges > 1 {
            let titleRange = Range(match.range(at: 1), in: html)
            let title = String(html[titleRange!])
            #expect(title == "Test Title")
        }
    }
}
