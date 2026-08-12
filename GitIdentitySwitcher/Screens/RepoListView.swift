import SwiftUI

struct RepoListView: View {
  
  // MARK: - Properties
  
  @EnvironmentObject var profileManager: ProfileManager
  @EnvironmentObject var repoManager: RepoManager
  @State private var pendingPath: String?
  @State private var selectedProfileID: UUID?
  
  // MARK: - Body
  
  var body: some View {
    Group {
      if let pendingPath {
        profilePicker(for: pendingPath)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      } else {
        listContent
          .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.15), value: pendingPath)
  }
  
  // MARK: - List Content
  
  private var listContent: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Tracked repositories")
        .font(.headline)
      
      ForEach(repoManager.repos) { repo in
        HStack {
          VStack(alignment: .leading) {
            Text((repo.path as NSString).lastPathComponent)
              .fontWeight(.medium)
            if let profile = profileManager.profiles.first(where: { $0.id == repo.expectedProfileID }) {
              Text("Expected: \(profile.label)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          Spacer()
          Button(role: .destructive) {
            repoManager.removeRepo(repo)
          } label: {
            Image(systemName: "trash")
          }
          .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
      }
      
      Button("Add repository...") {
        pickFolder()
      }
    }
    .padding(10)
  }
  
  // MARK: - Profile Picker
  
  private func profilePicker(for path: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Select expected profile for:")
        .font(.headline)
      Text(path)
        .font(.caption)
        .foregroundColor(.secondary)
      
      Picker("Profile", selection: $selectedProfileID) {
        ForEach(profileManager.profiles) { profile in
          Text(profile.label).tag(Optional(profile.id))
        }
      }
      
      HStack {
        Spacer()
        Button("Cancel") { resetPicker() }
        Button("Add") {
          if let id = selectedProfileID,
             let profile = profileManager.profiles.first(where: { $0.id == id }) {
            repoManager.addRepo(path: path, expectedProfile: profile)
          }
          resetPicker()
        }
        .disabled(selectedProfileID == nil)
      }
    }
    .padding(20)
  }
  
  // MARK: - Helpers
  
  private func resetPicker() {
    pendingPath = nil
    selectedProfileID = nil
  }
  
  private func pickFolder() {
    NSApp.activate(ignoringOtherApps: true)
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Add"
    if panel.runModal() == .OK, let url = panel.url {
      selectedProfileID = nil
      pendingPath = url.path
    }
  }
}
