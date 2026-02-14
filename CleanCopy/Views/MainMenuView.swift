import SwiftUI
import AppKit

struct MainMenuView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Controls
            HStack(spacing: 16) {
                Button(action: {
                    clipboardManager.processClipboardContent()
                }) {
                    Label("Convert URL", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Spacer()
                
                Menu {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { LoginItemManager.isEnabled },
                        set: { isEnabled in
                            if isEnabled {
                                LoginItemManager.register()
                            } else {
                                LoginItemManager.unregister()
                            }
                        }
                    ))
                    Divider()
                    Button("About") {
                        clipboardManager.showAbout()
                    }
                    Divider()
                    Button("Quit") {
                        clipboardManager.stopMonitoring()
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // History Section
            HistoryView(clipboardManager: clipboardManager)
        }
        .frame(width: 350, height: 450)
        .background(VisualEffectView(material: .menu, blendingMode: .behindWindow))
    }
}
