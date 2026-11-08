import SwiftUI

struct MenuBarRootView: View {
  @EnvironmentObject var profileManager: ProfileManager
  @EnvironmentObject var repoManager: RepoManager
  
  enum Tab: String, CaseIterable, Identifiable {
    case profiles = "Profiles"
    case repos = "Repositories"
    var id: String { rawValue }
  }
  
  enum EditorMode: Equatable {
    case add
    case edit(GitProfile)
    
    var profile: GitProfile? {
      switch self {
      case .add: return nil
      case .edit(let profile): return profile
      }
    }
  }
  
  @State private var selectedTab: Tab = .profiles
  @State private var editorMode: EditorMode?
  
  var body: some View {
    Group {
      if let editorMode {
        editor(for: editorMode)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      } else {
        mainScreen
          .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.15), value: editorMode)
  }
  
  private func editor(for mode: EditorMode) -> some View {
    ProfileEditView(
      profile: mode.profile,
      onSave: { profile in
        if profileManager.profiles.contains(where: { $0.id == profile.id }) {
          profileManager.updateProfile(profile)
        } else {
          profileManager.addProfile(profile)
        }
        editorMode = nil
      },
      onCancel: { editorMode = nil }
    )
  }
  
  private var mainScreen: some View {
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
          ProfileListView(
            onAddProfile: { editorMode = .add },
            onEditProfile: { editorMode = .edit($0) }
          )
        case .repos:
          RepoListView()
        }
      }
    }
    .frame(width: 300)
  }
}
