import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var loginItemEnabled: Bool = LoginItemManager.isEnabled
    
    var completion: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                if currentStep == 0 {
                    welcomeStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                } else if currentStep == 1 {
                    notificationsStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                } else {
                    loginItemStep
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .frame(maxHeight: .infinity)
            
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if currentStep < 2 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Finish") {
                        UserDefaults.standard.set(true, forKey: Constants.Keys.isOnboardingCompleted)
                        completion()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(width: 500, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            updateStatuses()
        }
    }
    
    private func updateStatuses() {
        Task {
            let status = await NotificationManager.shared.getAuthorizationStatus()
            await MainActor.run {
                self.notificationStatus = status
                self.loginItemEnabled = LoginItemManager.isEnabled
            }
        }
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .padding(.bottom, 8)
            
            Text("Welcome to \(Constants.appName)")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Simplify how you share web links by automatically converting URLs into rich text links with page titles.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 48)
        }
    }
    
    private var notificationsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .padding(.bottom, 8)
            
            Text("Stay Informed")
                .font(.title)
                .fontWeight(.bold)
            
            Text("\(Constants.appName) can notify you when a URL is successfully converted or if an error occurs.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 48)
            
            VStack(spacing: 8) {
                Button(notificationStatus == .authorized ? "Notifications Enabled" : "Enable Notifications") {
                    NotificationManager.shared.requestAuthorization()
                    // Poll for status change
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        updateStatuses()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(notificationStatus == .authorized)
                
                if notificationStatus == .authorized {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Notifications are active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if notificationStatus == .denied {
                    Text("Notifications are disabled in System Settings.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var loginItemStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "power.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.bottom, 8)
            
            Text("Launch at Login")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Keep CleanCopy ready to go by starting it automatically when you log in to your Mac.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 48)
            
            VStack(spacing: 8) {
                Button(loginItemEnabled ? "Enabled" : "Launch at Login") {
                    LoginItemManager.register()
                    updateStatuses()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(loginItemEnabled)
                
                if loginItemEnabled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Will start on login")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView(completion: {})
}
