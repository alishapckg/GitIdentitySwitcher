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
      
      Text("Hooks block commit/push when the active account doesn't match the expected one.")
        .font(.caption2)
        .foregroundColor(.secondary)
      
      ForEach(repoManager.repos) { repo in
        RepoRowView(
          repo: repo,
          profileManager: profileManager,
          onDelete: { repoManager.removeRepo(repo) }
        )
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
      selectedProfileID = profileManager.profiles.first?.id
      pendingPath = url.path
    }
  }
}

// MARK: - Repo Row

private struct RepoRowView: View {
  let repo: WatchedRepository
  @ObservedObject var profileManager: ProfileManager
  var onDelete: () -> Void
  
  @State private var currentName = ""
  @State private var currentEmail = ""
  @State private var didLoad = false
  
  var body: some View {
    let expected = profileManager.profiles.first { $0.id == repo.expectedProfileID }
    let isMatch = expected != nil
      && !currentEmail.isEmpty
      && expected!.email.lowercased() == currentEmail.lowercased()
    
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text((repo.path as NSString).lastPathComponent)
          .fontWeight(.medium)
        if let expected {
          Text("Expected: \(expected.label) · \(expected.name) <\(expected.email)>")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        if didLoad {
          HStack(spacing: 4) {
            Image(systemName: isMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(
              isMatch
                ? "Matches: \(currentName) <\(currentEmail)>"
                : "Mismatch! Active: \(currentName) <\(currentEmail)>"
            )
            .font(.caption2)
          }
          .foregroundColor(isMatch ? .green : .red)
        } else {
          HStack(spacing: 4) {
            ProgressView()
              .controlSize(.mini)
            Text("Checking identity…")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
      }
      Spacer()
      Button(role: .destructive) {
        onDelete()
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 2)
    .task(id: "\(repo.path)|\(profileManager.activeEmail)") {
      await fetchIdentity()
    }
  }
  
  private func fetchIdentity() async {
    let result = await Task.detached { [profileManager] in
      let name = profileManager.runGit(["config", "user.name"], cwd: repo.path)
      let email = profileManager.runGit(["config", "user.email"], cwd: repo.path)
      return (name, email)
    }.value
    currentName = result.0
    currentEmail = result.1
    didLoad = true
  }
}
