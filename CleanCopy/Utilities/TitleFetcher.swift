import Foundation
import os
import AppKit

class TitleFetcher {
    static let shared = TitleFetcher()
    
    private let network: NetworkService
    
    init(network: NetworkService = URLSession.shared) {
        self.network = network
    }
    
    func fetchTitle(for url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = Constants.Intervals.networkTimeout
        Logger.network.info("Fetching title for: \(url.absoluteString, privacy: .public)")
        
        let (data, response) = try await network.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return url.host ?? url.absoluteString
        }
        
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return url.host ?? url.absoluteString
        }
        
        let rawTitle = parseTitle(from: html, fallback: url.host ?? url.absoluteString)
        return await decodeHTMLEntities(rawTitle)
    }
    
    private func parseTitle(from html: String, fallback: String) -> String {
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

    private func decodeHTMLEntities(_ string: String) async -> String {
        guard string.contains("&") else { return string }

        return await MainActor.run {
            guard let data = string.data(using: .utf8) else { return string }
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                return attributedString.string
            }
            return string
        }
    }
}
