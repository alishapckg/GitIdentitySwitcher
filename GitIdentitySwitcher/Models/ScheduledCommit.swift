import Foundation

struct ScheduledCommit: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var repoPath: String
  var message: String
  /// Unix timestamp (seconds since 1970) at which the commit should run.
  var executeAt: TimeInterval
  /// Pre-formatted git date, so the commit keeps the intended timestamp and time zone.
  var authorDate: String
  var createdAt: TimeInterval = Date().timeIntervalSince1970

  var executeDate: Date {
    Date(timeIntervalSince1970: executeAt)
  }
}
