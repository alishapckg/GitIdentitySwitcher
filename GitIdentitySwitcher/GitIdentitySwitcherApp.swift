import SwiftUI

@main
struct GitIdentitySwitcherApp: App {
  @StateObject private var profileManager = ProfileManager()
  @StateObject private var repoManager = RepoManager()
  
  var body: some Scene {
    MenuBarExtra("Git ID", systemImage: "person.crop.circle.badge.checkmark") {
      MenuBarRootView()
        .environmentObject(profileManager)
        .environmentObject(repoManager)
    }
    .menuBarExtraStyle(.window)
  }
}