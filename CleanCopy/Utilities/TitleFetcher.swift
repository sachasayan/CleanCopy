import Foundation
import os

enum TitleFetcher {
    static func fetchTitle(for url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = Constants.Intervals.networkTimeout
        Logger.network.info("Fetching title for: \(url.absoluteString, privacy: .public)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return url.host ?? url.absoluteString
        }
        
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return url.host ?? url.absoluteString
        }
        
        return parseTitle(from: html, fallback: url.host ?? url.absoluteString)
    }
    
    private static func parseTitle(from html: String, fallback: String) -> String {
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
}
