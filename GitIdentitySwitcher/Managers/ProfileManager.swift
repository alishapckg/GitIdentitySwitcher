import Foundation
import Combine

class ProfileManager: ObservableObject {
  
  // MARK: - Properties
  
  @Published var profiles: [GitProfile] = []
  @Published var activeName: String = ""
  @Published var activeEmail: String = ""
  @Published var isSwitching: Bool = false
  
  
  // MARK: - Init
  
  init() {
    let stored = SharedStore.loadProfiles()
    if stored.isEmpty, !FileManager.default.fileExists(atPath: SharedStore.profilesURL.path) {
      profiles = [
        GitProfile(label: "Work", name: "Work Name", email: "you@work.com"),
        GitProfile(label: "Personal", name: "Personal Name", email: "you@personal.com")
      ]
      SharedStore.saveProfiles(profiles)
    } else {
      profiles = stored
    }
    Task {
      await refreshCurrentIdentity()
    }
  }
  
  
  // MARK: - Methods
  
  func addProfile(_ p: GitProfile) {
    profiles.append(p)
    SharedStore.saveProfiles(profiles)
  }
  
  func deleteProfile(_ p: GitProfile) {
    profiles.removeAll { $0.id == p.id }
    SharedStore.saveProfiles(profiles)
  }
  
  func updateProfile(_ p: GitProfile) {
    if let idx = profiles.firstIndex(where: { $0.id == p.id }) {
      profiles[idx] = p
      SharedStore.saveProfiles(profiles)
    }
  }
  
  func switchGlobalTo(_ profile: GitProfile) {
    guard !isSwitching else { return }
    isSwitching = true
    Task {
      await GitCommand.run(["config", "--global", "user.name", profile.name])
      await GitCommand.run(["config", "--global", "user.email", profile.email])
      await refreshCurrentIdentity()
      await MainActor.run {
        self.isSwitching = false
      }
    }
  }
  
  func refreshCurrentIdentity() async {
    let name = await GitCommand.run(["config", "--global", "user.name"]).output
    let email = await GitCommand.run(["config", "--global", "user.email"]).output
    await MainActor.run {
      self.activeName = name
      self.activeEmail = email
    }
  }
}
