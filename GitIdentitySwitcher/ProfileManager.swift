import Foundation
import Combine

class ProfileManager: ObservableObject {
  @Published var profiles: [GitProfile] = []
  @Published var activeName: String = ""
  @Published var activeEmail: String = ""
  
  init() {
    profiles = SharedStore.loadProfiles()
    if profiles.isEmpty {
      profiles = [
        GitProfile(label: "Work", name: "Work Name", email: "you@work.com"),
        GitProfile(label: "Personal", name: "Personal Name", email: "you@personal.com")
      ]
      SharedStore.saveProfiles(profiles)
    }
    refreshCurrentIdentity()
  }
  
  func addProfile(_ p: GitProfile) {
    profiles.append(p)
    SharedStore.saveProfiles(profiles)
  }
  
  func deleteProfile(_ p: GitProfile) {
    profiles.removeAll { $0.id == p.id }
    SharedStore.saveProfiles(profiles)
  }
  
  func switchGlobalTo(_ profile: GitProfile) {
    runGit(["config", "--global", "user.name", profile.name])
    runGit(["config", "--global", "user.email", profile.email])
    refreshCurrentIdentity()
  }
  
  func refreshCurrentIdentity() {
    activeName = runGit(["config", "--global", "user.name"])
    activeEmail = runGit(["config", "--global", "user.email"])
  }
  
  @discardableResult
  func runGit(_ args: [String], cwd: String? = nil) -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    task.arguments = args
    if let cwd = cwd {
      task.currentDirectoryURL = URL(fileURLWithPath: cwd)
    }
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}
