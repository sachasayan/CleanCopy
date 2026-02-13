import AppKit
import Foundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        let isOnboardingCompleted = UserDefaults.standard.bool(forKey: Constants.Keys.isOnboardingCompleted)
        
        if !isOnboardingCompleted {
            showOnboarding()
        } else {
            NotificationManager.shared.requestAuthorization()
        }
    }
    
    private func showOnboarding() {
        let onboardingView = OnboardingView { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            NotificationManager.shared.requestAuthorization()
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: onboardingView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.onboardingWindow = window
    }
}
