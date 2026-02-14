import SwiftUI

@main
struct CleanCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var clipboardManager = ClipboardManager()

    var body: some Scene {
        MenuBarExtra {
            MainMenuView(clipboardManager: clipboardManager)
        } label: {
            Group {
                switch clipboardManager.status {
                case .idle:
                    Image(systemName: "link.circle")
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
