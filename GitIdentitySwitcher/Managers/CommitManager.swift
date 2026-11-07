import Foundation
import Combine

@MainActor
final class CommitManager: ObservableObject {
  @Published var isCommitting: Bool = false
  @Published var lastResult: String = ""
  @Published var lastResultIsError: Bool = false

  /// Stages all changes, creates a commit with the given date, and pushes it.
  func commitAndPush(repoPath: String, message: String, date: Date) async {
    guard !isCommitting, !repoPath.isEmpty else { return }

    isCommitting = true
    defer { isCommitting = false }

    await GitCommand.run(["add", "."], in: repoPath)

    // Git understands ISO 8601 dates with an explicit time zone offset.
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    let dateString = formatter.string(from: date)

    let result = await GitCommand.run(
      ["commit", "-m", message],
      in: repoPath,
      environment: [
        "GIT_AUTHOR_DATE": dateString,
        "GIT_COMMITTER_DATE": dateString
      ]
    )

    if result.isSuccess {
      let commitSummary = result.output.isEmpty ? "Commit created." : result.output
      let pushResult = await push(repoPath: repoPath)
      if pushResult.isSuccess {
        lastResult = "\(commitSummary)\nPushed to remote."
        lastResultIsError = false
      } else {
        let details = pushResult.errorOutput.isEmpty ? pushResult.output : pushResult.errorOutput
        lastResult = "\(commitSummary)\nPush failed: \(details)"
        lastResultIsError = true
      }
    } else {
      let details = result.errorOutput.isEmpty ? result.output : result.errorOutput
      lastResult = "Error: \(details)"
      lastResultIsError = true
    }
  }

  /// Pushes the current branch. If it has no upstream yet, sets origin/HEAD as upstream.
  private func push(repoPath: String) async -> GitCommandResult {
    let environment = ["GIT_TERMINAL_PROMPT": "0"]
    let result = await GitCommand.run(["push"], in: repoPath, environment: environment)
    guard !result.isSuccess else { return result }

    let error = result.errorOutput.lowercased()
    let needsUpstream = error.contains("no upstream")
      || error.contains("no configured push destination")
      || error.contains("has no upstream branch")
    guard needsUpstream else { return result }

    return await GitCommand.run(
      ["push", "-u", "origin", "HEAD"],
      in: repoPath,
      environment: environment
    )
  }

  func report(_ message: String, isError: Bool) {
    lastResult = message
    lastResultIsError = isError
  }
}
