import SwiftUI

struct HistoryItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onConvert: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: item.type.iconName)
                .font(.system(size: 14))
                .foregroundColor(item.type == .convertedLink ? .accentColor : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayContent)
                    .lineLimit(1)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(item.type == .convertedLink ? .primary : .primary.opacity(0.9))
                
                Text(item.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 8) {
                    if item.type == .url {
                        Button(action: onConvert) {
                            Text("Convert")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
