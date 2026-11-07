import SwiftUI

@main
struct GitIdentitySwitcherApp: App {
  @StateObject private var profileManager = ProfileManager()
  @StateObject private var repoManager = RepoManager()
  @StateObject private var scheduledCommitManager = ScheduledCommitManager()
  
  var body: some Scene {
    MenuBarExtra("Git ID", systemImage: "person.crop.circle.badge.checkmark") {
      MenuBarRootView()
        .environmentObject(profileManager)
        .environmentObject(repoManager)
        .environmentObject(scheduledCommitManager)
    }
    .menuBarExtraStyle(.window)
    
    // Keep the identifier in sync with the value used in RepoRowView.
    Window("Custom Commit", id: "custom-commit-window") {
      CustomCommitView()
        .environmentObject(repoManager)
        .environmentObject(scheduledCommitManager)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }
}
