import SwiftUI

struct MenuBarRootView: View {
  @EnvironmentObject var profileManager: ProfileManager
  @EnvironmentObject var repoManager: RepoManager
  
  enum Tab: String, CaseIterable, Identifiable {
    case profiles = "Profiles"
    case repos = "Repositories"
    var id: String { rawValue }
  }
  
  @State private var selectedTab: Tab = .profiles
  
  var body: some View {
    VStack(spacing: 0) {
      Picker("", selection: $selectedTab) {
        ForEach(Tab.allCases) { tab in
          Text(tab.rawValue).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal, 10)
      .padding(.top, 10)
      .padding(.bottom, 6)
      
      Divider()
      
      Group {
        switch selectedTab {
        case .profiles:
          ProfileListView()
        case .repos:
          RepoListView()
        }
      }
    }
    .frame(width: 300)
  }
}
