import SwiftUI

struct RepoListView: View {
  
  // MARK: - Properties
  
  @EnvironmentObject var profileManager: ProfileManager
  @EnvironmentObject var repoManager: RepoManager
  
  enum Target: Equatable {
    case add(String)
    case change(WatchedRepository)
    
    var path: String {
      switch self {
      case .add(let path): return path
      case .change(let repo): return repo.path
      }
    }
  }
  
  @State private var target: Target?
  @State private var selectedProfileID: UUID?
  @State private var showDuplicateAlert = false
  
  // MARK: - Body
  
  var body: some View {
    Group {
      if let target {
        profilePicker(for: target)
          .transition(.move(edge: .trailing).combined(with: .opacity))
      } else {
        listContent
          .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.15), value: target)
    .alert("Already tracked", isPresented: $showDuplicateAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("This repository is already in the list.")
    }
  }
  
  // MARK: - List Content
  
  private var listContent: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Tracked repositories")
        .font(.headline)
      
      Text("Hooks block commit/push when the active account doesn't match the expected one. Right-click a repo to change its expected profile.")
        .font(.caption2)
        .foregroundColor(.secondary)
      
      ForEach(repoManager.repos) { repo in
        RepoRowView(
          repo: repo,
          profileManager: profileManager,
          onDelete: { repoManager.removeRepo(repo) },
          onChangeProfile: {
            selectedProfileID = repo.expectedProfileID
            target = .change(repo)
          }
        )
      }
      
      Button("Add repository...") {
        pickFolder()
      }
    }
    .padding(10)
  }
  
  // MARK: - Profile Picker
  
  private func profilePicker(for target: Target) -> some View {
    let isChange: Bool
    switch target {
    case .add: isChange = false
    case .change: isChange = true
    }
    
    return VStack(alignment: .leading, spacing: 12) {
      Text(isChange ? "Change expected profile for:" : "Select expected profile for:")
        .font(.headline)
      Text(target.path)
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
        Button(isChange ? "Update" : "Add") {
          guard let id = selectedProfileID,
                let profile = profileManager.profiles.first(where: { $0.id == id }) else { return }
          switch target {
          case .add(let path):
            repoManager.addRepo(path: path, expectedProfile: profile)
          case .change(let repo):
            repoManager.updateExpectedProfile(for: repo.id, to: profile)
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
    target = nil
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
      let path = url.path
      if repoManager.isTracked(path) {
        showDuplicateAlert = true
      } else {
        selectedProfileID = profileManager.profiles.first?.id
        target = .add(path)
      }
    }
  }
}

// MARK: - Repo Row

struct RepoRowView: View {
  let repo: WatchedRepository
  @ObservedObject var profileManager: ProfileManager
  var onDelete: () -> Void
  var onChangeProfile: () -> Void
  
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
    .contextMenu {
      Button("Change expected profile…") { onChangeProfile() }
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
    .task(id: "\(repo.path)|\(profileManager.activeEmail)") {
      await fetchIdentity()
    }
  }
  
  private func fetchIdentity() async {
    let result = await Task.detached { [profileManager] in
      let output = profileManager.runGit(["config", "--list"], cwd: repo.path)
      var name = ""
      var email = ""
      for line in output.split(separator: "\n") {
        guard let eq = line.firstIndex(of: "=") else { continue }
        let key = line[..<eq].lowercased()
        let value = String(line[line.index(after: eq)...])
        if key == "user.name" { name = value }
        else if key == "user.email" { email = value }
      }
      return (name, email)
    }.value
    currentName = result.0
    currentEmail = result.1
    didLoad = true
  }
}