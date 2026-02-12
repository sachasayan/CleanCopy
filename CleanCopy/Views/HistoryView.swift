import SwiftUI

struct HistoryView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clipboard History")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if !clipboardManager.history.isEmpty {
                    Button("Clear") {
                        clipboardManager.clearHistory()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
            
            Divider()

            if clipboardManager.history.isEmpty {
                VStack {
                    Image(systemName: "history")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.bottom, 4)
                    Text("No Activity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(clipboardManager.history) { item in
                        HistoryItemRow(item: item, onCopy: {
                            clipboardManager.copyToClipboard(item)
                        }, onConvert: {
                            clipboardManager.convertHistoryItem(item)
                        }, onDelete: {
                            clipboardManager.deleteHistoryItem(item)
                        })
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
