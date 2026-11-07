import Foundation
import Combine
import Darwin

@MainActor
final class ScheduledCommitManager: ObservableObject {
  static let labelPrefix = "ns.GitIdentitySwitcher.commit."
  static let launchAgentsDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/LaunchAgents", isDirectory: true)

  @Published private(set) var jobs: [ScheduledCommit] = []

  private var refreshTimer: Timer?

  init() {
    jobs = SharedStore.loadScheduledCommits()
    installScript()
    Task {
      reconcile()
    }
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refresh()
      }
    }
  }

  deinit {
    refreshTimer?.invalidate()
  }

  // MARK: - Queries

  func jobs(for repoPath: String) -> [ScheduledCommit] {
    let normalized = (repoPath as NSString).standardizingPath
    return jobs
      .filter { ($0.repoPath as NSString).standardizingPath == normalized }
      .sorted { $0.executeAt < $1.executeAt }
  }

  // MARK: - Mutations

  @discardableResult
  func schedule(repoPath: String, message: String, date: Date) -> ScheduledCommit {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

    let job = ScheduledCommit(
      repoPath: repoPath,
      message: message,
      executeAt: date.timeIntervalSince1970,
      authorDate: formatter.string(from: date)
    )

    withLock {
      var stored = SharedStore.loadScheduledCommits()
      stored.append(job)
      SharedStore.saveScheduledCommits(stored)
      jobs = stored.sorted { $0.executeAt < $1.executeAt }
    }

    installScript()
    installLaunchAgent(for: job)
    return job
  }

  func cancel(_ job: ScheduledCommit) {
    withLock {
      var stored = SharedStore.loadScheduledCommits()
      stored.removeAll { $0.id == job.id }
      SharedStore.saveScheduledCommits(stored)
      jobs = stored
    }
    removeLaunchAgent(for: job)
  }

  /// Re-reads the queue, e.g. after a launch agent executed a job.
  func refresh() {
    withLock {
      jobs = SharedStore.loadScheduledCommits()
    }
  }

  // MARK: - Queue locking

  private func withLock<T>(_ body: () -> T) -> T {
    let descriptor = open(SharedStore.schedulerLockURL.path, O_CREAT | O_RDWR, 0o644)
    guard descriptor >= 0 else { return body() }

    flock(descriptor, LOCK_EX)
    defer {
      flock(descriptor, LOCK_UN)
      close(descriptor)
    }
    return body()
  }

  // MARK: - Launch agent

  private func reconcile() {
    installScript()

    let validIDs = Set(jobs.map(\.id))
    for url in plistURLs() {
      guard let id = jobID(fromPlistURL: url), !validIDs.contains(id) else { continue }
      runLaunchctl(["bootout", "gui/\(getuid())/\(label(for: id))"])
      try? FileManager.default.removeItem(at: url)
    }

    for job in jobs {
      installLaunchAgent(for: job)
    }
  }

  private func installLaunchAgent(for job: ScheduledCommit) {
    guard writePlist(for: job) else { return }

    let label = label(for: job.id)
    guard !isAgentLoaded(label: label) else { return }

    let status = runLaunchctl([
      "bootstrap", "gui/\(getuid())", plistURL(for: job.id).path
    ])
    if status != 0 {
      runLaunchctl(["load", "-w", plistURL(for: job.id).path])
    }
  }

  private func removeLaunchAgent(for job: ScheduledCommit) {
    runLaunchctl(["bootout", "gui/\(getuid())/\(label(for: job.id))"])
    try? FileManager.default.removeItem(at: plistURL(for: job.id))
  }

  private func writePlist(for job: ScheduledCommit) -> Bool {
    let components = Calendar.current.dateComponents(
      [.month, .day, .hour, .minute],
      from: job.executeDate
    )
    var interval: [String: Int] = [:]
    if let month = components.month { interval["Month"] = month }
    if let day = components.day { interval["Day"] = day }
    if let hour = components.hour { interval["Hour"] = hour }
    if let minute = components.minute { interval["Minute"] = minute }

    let plist: [String: Any] = [
      "Label": label(for: job.id),
      "ProgramArguments": [
        "/usr/bin/env", "python3",
        SharedStore.schedulerScriptURL.path,
        job.id.uuidString
      ],
      "EnvironmentVariables": [
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      ],
      "StartCalendarInterval": interval,
      "RunAtLoad": true,
      "StandardOutPath": SharedStore.schedulerOutLogURL.path,
      "StandardErrorPath": SharedStore.schedulerErrLogURL.path
    ]

    do {
      try FileManager.default.createDirectory(
        at: Self.launchAgentsDirectory,
        withIntermediateDirectories: true
      )
      let data = try PropertyListSerialization.data(
        fromPropertyList: plist,
        format: .xml,
        options: 0
      )
      try data.write(to: plistURL(for: job.id), options: .atomic)
      return true
    } catch {
      return false
    }
  }

  private func isAgentLoaded(label: String) -> Bool {
    runLaunchctl(["print", "gui/\(getuid())/\(label)"]) == 0
  }

  @discardableResult
  private func runLaunchctl(_ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus
    } catch {
      return -1
    }
  }

  private func plistURL(for id: UUID) -> URL {
    Self.launchAgentsDirectory.appendingPathComponent("\(label(for: id)).plist")
  }

  private func label(for id: UUID) -> String {
    "\(Self.labelPrefix)\(id.uuidString)"
  }

  private func jobID(fromPlistURL url: URL) -> UUID? {
    let name = url.deletingPathExtension().lastPathComponent
    guard name.hasPrefix(Self.labelPrefix) else { return nil }
    return UUID(uuidString: String(name.dropFirst(Self.labelPrefix.count)))
  }

  private func plistURLs() -> [URL] {
    let contents = try? FileManager.default.contentsOfDirectory(
      at: Self.launchAgentsDirectory,
      includingPropertiesForKeys: nil
    )
    return (contents ?? []).filter {
      $0.lastPathComponent.hasPrefix(Self.labelPrefix) && $0.pathExtension == "plist"
    }
  }

  // MARK: - Runner script

  private func installScript() {
    try? Self.script.write(
      to: SharedStore.schedulerScriptURL,
      atomically: true,
      encoding: .utf8
    )
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: SharedStore.schedulerScriptURL.path
    )
  }

  private static let script = #"""
  #!/usr/bin/env python3
  import fcntl
  import json
  import os
  import subprocess
  import sys
  import time

  BASE = os.environ.get("GIS_BASE") or os.path.expanduser(
      "~/Library/Application Support/GitIdentitySwitcher"
  )
  JOBS_FILE = os.path.join(BASE, "scheduled-commits.json")
  LOG_FILE = os.path.join(BASE, "scheduled-commits.log")
  LOCK_FILE = os.path.join(BASE, "scheduler.lock")
  LAUNCH_AGENTS = os.environ.get("GIS_LAUNCH_AGENTS") or os.path.expanduser(
      "~/Library/LaunchAgents"
  )
  LABEL_PREFIX = "ns.GitIdentitySwitcher.commit."


  def log(message):
      try:
          with open(LOG_FILE, "a") as handle:
              handle.write(time.strftime("%Y-%m-%d %H:%M:%S ") + message + "\n")
      except Exception:
          pass


  def cleanup(label):
      plist = os.path.join(LAUNCH_AGENTS, label + ".plist")
      try:
          os.remove(plist)
      except OSError:
          pass
      try:
          subprocess.run(
              ["/bin/launchctl", "bootout", "gui/%d/%s" % (os.getuid(), label)],
              stdout=subprocess.DEVNULL,
              stderr=subprocess.DEVNULL,
              check=False,
          )
      except Exception:
          pass


  def main():
      if len(sys.argv) < 2:
          return

      job_id = sys.argv[1]
      label = LABEL_PREFIX + job_id

      os.makedirs(BASE, exist_ok=True)
      lock = open(LOCK_FILE, "w")
      try:
          fcntl.flock(lock, fcntl.LOCK_EX)
      except OSError:
          pass

      try:
          with open(JOBS_FILE) as handle:
              jobs = json.load(handle)
      except Exception:
          jobs = []

      job = next((item for item in jobs if item.get("id") == job_id), None)
      if job is None:
          lock.close()
          cleanup(label)
          return

      if float(job.get("executeAt", 0)) > time.time():
          lock.close()
          return

      remaining = [item for item in jobs if item.get("id") != job_id]
      try:
          temporary = JOBS_FILE + ".tmp"
          with open(temporary, "w") as handle:
              json.dump(remaining, handle, indent=2)
          os.replace(temporary, JOBS_FILE)
      except Exception as error:
          log("Could not update the queue: %s" % error)

      lock.close()

      repo = job.get("repoPath", "")
      message = job.get("message", "")
      author_date = job.get("authorDate", "")

      environment = os.environ.copy()
      environment["GIT_TERMINAL_PROMPT"] = "0"
      if author_date:
          environment["GIT_AUTHOR_DATE"] = author_date
          environment["GIT_COMMITTER_DATE"] = author_date

      try:
          subprocess.run(
              ["/usr/bin/git", "-C", repo, "add", "."],
              env=environment,
              stdout=subprocess.DEVNULL,
              stderr=subprocess.DEVNULL,
              check=False,
          )
          result = subprocess.run(
              ["/usr/bin/git", "-C", repo, "commit", "-m", message],
              env=environment,
              capture_output=True,
              text=True,
              check=False,
          )
          if result.returncode == 0:
              log("OK commit %s: %s" % (repo, (result.stdout or "").strip()))

              push = subprocess.run(
                  ["/usr/bin/git", "-C", repo, "push"],
                  env=environment,
                  capture_output=True,
                  text=True,
                  check=False,
              )
              push_output = ((push.stderr or "") + (push.stdout or "")).lower()
              needs_upstream = (
                  "no upstream" in push_output
                  or "no configured push destination" in push_output
                  or "has no upstream branch" in push_output
              )
              if push.returncode != 0 and needs_upstream:
                  push = subprocess.run(
                      ["/usr/bin/git", "-C", repo, "push", "-u", "origin", "HEAD"],
                      env=environment,
                      capture_output=True,
                      text=True,
                      check=False,
                  )

              if push.returncode == 0:
                  log("OK push %s: %s" % (repo, (push.stdout or push.stderr or "").strip()))
              else:
                  log("FAIL push %s: %s" % (repo, (push.stderr or push.stdout or "").strip()))
          else:
              log("FAIL commit %s: %s" % (repo, (result.stderr or result.stdout or "").strip()))
      except Exception as error:
          log("ERROR %s: %s" % (repo, error))

      cleanup(label)


  if __name__ == "__main__":
      main()
  """#
}
