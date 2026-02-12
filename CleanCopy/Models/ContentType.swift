import Foundation

enum ContentType: String, Equatable {
    case text
    case url
    case richText
    case convertedLink
    
    var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .richText: return "doc.richtext"
        case .convertedLink: return "link.circle.fill"
        }
    }
}
