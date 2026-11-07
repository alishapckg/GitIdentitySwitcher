import Foundation

enum SharedStore {
  static var baseDirectory: URL? {
    guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("GitIdentitySwitcher", isDirectory: true) else { return nil  }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
  
  static var profilesURL: URL {
    guard let baseDirectory else { return URL.currentDirectory() }
    return baseDirectory.appendingPathComponent("profiles.json")
  }
  
  static var reposURL: URL {
    guard let baseDirectory else { return URL.currentDirectory() }
    return baseDirectory.appendingPathComponent("repos.json")
  }
  
  static var scheduledCommitsURL: URL {
    guard let baseDirectory else { return URL.currentDirectory() }
    return baseDirectory.appendingPathComponent("scheduled-commits.json")
  }
  
  static var schedulerScriptURL: URL {
    guard let baseDirectory else { return URL.currentDirectory() }
    return baseDirectory.appendingPathComponent("scheduler.py")
  }
  
  static var schedulerLogURL: URL {
    guard let baseDirectory else { return URL.currentDirectory() }
    return baseDirectory.appendingPathComponent("scheduled-commits.log")
  }
  
  static var schedulerOutLogURL: URL {
    guard let baseDirectory else { return URL.currentDirectory() }
    return baseDirectory.appendingPathComponent("scheduler.out.log")
  }
  
  static var schedulerErrLogURL: URL {
    guard let baseDirectory else { return URL.currentDirectory() }
    return baseDirectory.appendingPathComponent("scheduler.err.log")
  }
  
  static var schedulerLockURL: URL {
    guard let baseDirectory else { return URL.currentDirectory() }
    return baseDirectory.appendingPathComponent("scheduler.lock")
  }
  
  
  // MARK: - Methods
  
  static func loadProfiles() -> [GitProfile] {
    guard let data = try? Data(contentsOf: profilesURL),
          let decoded = try? JSONDecoder().decode([GitProfile].self, from: data) else { return [] }
    return decoded
  }
  
  static func saveProfiles(_ profiles: [GitProfile]) {
    if let data = try? JSONEncoder().encode(profiles) {
      try? data.write(to: profilesURL)
    }
  }
  
  static func loadRepos() -> [WatchedRepository] {
    guard let data = try? Data(contentsOf: reposURL),
          let decoded = try? JSONDecoder().decode([WatchedRepository].self, from: data) else { return [] }
    
    return decoded
  }
  
  static func saveRepos(_ repos: [WatchedRepository]) {
    if let data = try? JSONEncoder().encode(repos) {
      try? data.write(to: reposURL)
    }
  }
  
  static func loadScheduledCommits() -> [ScheduledCommit] {
    guard let data = try? Data(contentsOf: scheduledCommitsURL),
          let decoded = try? JSONDecoder().decode([ScheduledCommit].self, from: data) else { return [] }
    return decoded
  }
  
  static func saveScheduledCommits(_ commits: [ScheduledCommit]) {
    if let data = try? JSONEncoder().encode(commits) {
      try? data.write(to: scheduledCommitsURL, options: .atomic)
    }
  }
}
