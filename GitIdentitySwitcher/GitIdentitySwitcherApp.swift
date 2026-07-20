import SwiftUI

@main
struct GitIdentitySwitcherApp: App {
  
  // MARK: - Parameters
  
  @StateObject private var profileManager = ProfileManager()
  @StateObject private var repoManager = RepoManager()
  
  
  // MARK: - Body
  
  var body: some Scene {
    MenuBarExtra("Git ID", systemImage: "person.crop.circle.badge.checkmark") {
      TabView {
        ProfileListView()
          .environmentObject(profileManager)
          .tabItem {
            Text("Profiles")
          }
        
        RepoListView()
          .environmentObject(profileManager)
          .environmentObject(repoManager)
          .tabItem {
            Text("Repositories")
          }
      }
    }
    .menuBarExtraStyle(.window)
  }
}
