import SwiftUI

@main
struct GitIdentitySwitcherApp: App {
  @StateObject private var profileManager = ProfileManager()
  @StateObject private var repoManager = RepoManager()
  
  var body: some Scene {
    MenuBarExtra("Git ID", systemImage: "person.crop.circle.badge.checkmark") {
      TabView {
        ProfileListView()
          .environmentObject(profileManager)
          .tabItem { Text("Profiles") }
        
        RepoListView()
          .environmentObject(profileManager)
          .environmentObject(repoManager)
          .tabItem { Text("Repositories") }
      }
      .frame(width: 300, height: 400)
    }
    .menuBarExtraStyle(.window)
  }
}
