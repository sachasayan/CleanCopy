import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let displayContent: String
    let timestamp: Date
    let type: ContentType
    
    init(content: String, displayContent: String? = nil, type: ContentType = .text) {
        self.id = UUID()
        self.content = content
        self.displayContent = displayContent ?? content
        self.timestamp = Date()
        self.type = type
    }
}
