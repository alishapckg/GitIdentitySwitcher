import Foundation
import Combine

class RepoManager: ObservableObject {
  
  // MARK: - Properties
  
  @Published var repos: [WatchedRepository] = []
  
  
  // MARK: - Init
  
  init() {
    repos = SharedStore.loadRepos()
    repairModifiedConfig()
    for repo in repos {
      installHooks(in: repo.path)
    }
  }
  
  
  // MARK: - Methods
  
  func isTracked(_ path: String) -> Bool {
    let normalized = (path as NSString).standardizingPath
    return repos.contains { repo in
      (repo.path as NSString).standardizingPath == normalized
    }
  }
  
  func addRepo(path: String, expectedProfile: GitProfile) {
    guard !isTracked(path) else { return }
    var repo = WatchedRepository(path: path, expectedProfileID: expectedProfile.id)
    installHooks(in: path)
    repo.hooksInstalled = true
    repos.append(repo)
    SharedStore.saveRepos(repos)
  }
  
  func removeRepo(_ repo: WatchedRepository) {
    uninstallHooks(in: repo.path)
    repos.removeAll { $0.id == repo.id }
    SharedStore.saveRepos(repos)
  }
  
  
  // MARK: - Hook installation
  
  private func hookScript(hookName: String) -> String {
    // Script compares current email of repository with expected email from repos.json,
    // using python3 for json parsing.
    let lines = [
      "#!/bin/bash",
      "REPO_PATH=\"$(git rev-parse --show-toplevel 2>/dev/null)\"",
      "CURRENT_EMAIL=\"$(git config user.email)\"",
      "",
      "RESULT=$(python3 - \"$REPO_PATH\" \"$CURRENT_EMAIL\" << 'PYEOF'",
      "import json, sys, os",
      "",
      "repo_path = sys.argv[1]",
      "current_email = sys.argv[2]",
      "",
      "base = os.path.expanduser(\"~/Library/Application Support/GitIdentitySwitcher\")",
      "repos_file = os.path.join(base, \"repos.json\")",
      "profiles_file = os.path.join(base, \"profiles.json\")",
      "",
      "try:",
      "    with open(repos_file) as f:",
      "        repos = json.load(f)",
      "    with open(profiles_file) as f:",
      "        profiles = json.load(f)",
      "except Exception:",
      "    print(\"OK\")",
      "    sys.exit(0)",
      "",
      "repo_entry = next((r for r in repos if os.path.normpath(r[\"path\"]) == os.path.normpath(repo_path)), None)",
      "if repo_entry is None:",
      "    print(\"OK\")",
      "    sys.exit(0)",
      "",
      "profile = next((p for p in profiles if p[\"id\"] == repo_entry[\"expectedProfileID\"]), None)",
      "if profile is None:",
      "    print(\"OK\")",
      "    sys.exit(0)",
      "",
      "if profile[\"email\"].lower() != current_email.lower():",
      "    print(f\"MISMATCH|{profile['label']}|{profile['email']}|{current_email}\")",
      "else:",
      "    print(\"OK\")",
      "PYEOF",
      ")",
      "",
      "if [[ \"$RESULT\" == MISMATCH* ]]; then",
      "    IFS='|' read -r _ EXPECTED_LABEL EXPECTED_EMAIL CURRENT <<< \"$RESULT\"",
      "    BUTTON=$(osascript << APPLE 2>/dev/null",
      "button returned of (display alert \"Wrong git-account!\" message \"Expected profile '$EXPECTED_LABEL' ($EXPECTED_EMAIL), but now active is: $CURRENT.\" buttons {\"Cancel\", \"Continue anyway\"} default button \"Cancel\" as critical)",
      "APPLE",
      ")",
      "    if [[ \"$BUTTON\" == \"Cancel\" ]]; then",
      "        echo \"Operation \(hookName) canceled: mismatched git-accounts.\" 1>&2",
      "        exit 1",
      "    fi",
      "fi",
      "exit 0"
    ]
    return lines.joined(separator: "\n")
  }
  
  func installHooks(in repoPath: String) {
    let hooksDir = "\(repoPath)/.git/hooks"
    guard FileManager.default.fileExists(atPath: hooksDir) else { return }
    
    // pre-commit, pre-push cover commit и push.
    // post-merge covers git pull (merge-part).
    // reference-transaction catches git fetch (update of refs).
    let hooks = ["pre-commit", "pre-push", "post-merge", "reference-transaction"]
    
    for hook in hooks {
      let path = "\(hooksDir)/\(hook)"
      let script = hookScript(hookName: hook)
      try? script.write(toFile: path, atomically: true, encoding: .utf8)
      try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }
  }
  
  func uninstallHooks(in repoPath: String) {
    let hooksDir = "\(repoPath)/.git/hooks"
    for hook in ["pre-commit", "pre-push", "post-merge", "reference-transaction"] {
      try? FileManager.default.removeItem(atPath: "\(hooksDir)/\(hook)")
    }
  }
  
  // MARK: - Config repair
  
  private func repairModifiedConfig() {
    for repo in repos {
      let name = runGit(["config", "--local", "user.name"], cwd: repo.path)
      if name.caseInsensitiveCompare("user.email") == .orderedSame {
        runGit(["config", "--unset", "--local", "user.name"], cwd: repo.path)
      }
    }
  }
  
  @discardableResult
  private func runGit(_ args: [String], cwd: String) -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    task.arguments = args
    task.currentDirectoryURL = URL(fileURLWithPath: cwd)
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}
