import SwiftUI
import UniformTypeIdentifiers

struct RepoListView: View {
  
  // MARK: - Properties
  
  @EnvironmentObject var profileManager: ProfileManager
  @EnvironmentObject var repoManager: RepoManager
  @State private var showingPicker = false
  @State private var pendingPath: String?
  @State private var selectedProfileID: UUID?
  
  var body: some View {
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
        showingPicker = true
      }
    }
    .padding(10)
    .frame(width: 280)
    .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.folder]) { result in
      if case .success(let url) = result {
        pendingPath = url.path
      }
    }
    .sheet(item: Binding(
      get: { pendingPath.map { PathWrapper(path: $0) } },
      set: { pendingPath = $0?.path }
    )) { wrapper in
      VStack(alignment: .leading, spacing: 12) {
        Text("Select expected profile for:")
          .font(.headline)
        Text(wrapper.path).font(.caption).foregroundColor(.secondary)
        
        Picker("Profile", selection: $selectedProfileID) {
          ForEach(profileManager.profiles) { profile in
            Text(profile.label).tag(Optional(profile.id))
          }
        }
        
        HStack {
          Spacer()
          Button("Cancel") { pendingPath = nil }
          Button("Add") {
            if let id = selectedProfileID,
               let profile = profileManager.profiles.first(where: { $0.id == id }) {
              repoManager.addRepo(path: wrapper.path, expectedProfile: profile)
            }
            pendingPath = nil
          }
          .disabled(selectedProfileID == nil)
        }
      }
      .padding(20)
      .frame(width: 320)
    }
  }
}
