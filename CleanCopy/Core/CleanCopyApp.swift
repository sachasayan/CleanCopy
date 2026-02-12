import SwiftUI

@main
struct CleanCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var clipboardManager = ClipboardManager()

    var body: some Scene {
        MenuBarExtra(Constants.appName, systemImage: "link.circle") {
            MainMenuView(clipboardManager: clipboardManager)
        }
        .menuBarExtraStyle(.window)
    }
}
