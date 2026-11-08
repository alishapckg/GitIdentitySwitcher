import SwiftUI

struct CustomCommitView: View {
  // The path is written here by RepoRowView before the window is opened.
  @EnvironmentObject var repoManager: RepoManager
  @EnvironmentObject var scheduler: ScheduledCommitManager
  @StateObject private var commitManager = CommitManager()

  @State private var commitMessage: String = ""
  @State private var selectedDate: Date = Date()
  @State private var showResult: Bool = false

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private var isFutureCommit: Bool {
    selectedDate.timeIntervalSinceNow > 120
  }

  private var pendingJobs: [ScheduledCommit] {
    scheduler.jobs(for: repoManager.targetRepoPathForCommit)
  }

  var body: some View {
    VStack(spacing: 16) {
      Text("Custom Commit")
        .font(.title2)
        .fontWeight(.semibold)

      // Repository path (taken automatically from repoManager)
      VStack(alignment: .leading, spacing: 6) {
        Text("Repository:")
          .font(.caption)
          .foregroundColor(.secondary)
        Text(repoManager.targetRepoPathForCommit)
          .font(.system(.body, design: .monospaced))
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.secondary.opacity(0.1))
          .cornerRadius(6)
          .lineLimit(2)
      }

      // Commit message
      VStack(alignment: .leading, spacing: 6) {
        Text("Commit message:")
          .font(.caption)
          .foregroundColor(.secondary)
        TextField("Enter a message...", text: $commitMessage)
          .textFieldStyle(.roundedBorder)
      }

      // Calendar and time
      VStack(alignment: .leading, spacing: 8) {
        Text("Commit date and time:")
          .font(.caption)
          .foregroundColor(.secondary)

        DateTimePicker(selection: $selectedDate)

        Text(
          isFutureCommit
            ? "The commit will run and push automatically at the selected time, even if the app is closed."
            : "The commit will be created and pushed immediately."
        )
        .font(.caption2)
        .foregroundColor(.secondary)
      }

      // Action button
      Button(action: {
        guard !commitMessage.isEmpty else { return }

        if isFutureCommit {
          let job = scheduler.schedule(
            repoPath: repoManager.targetRepoPathForCommit,
            message: commitMessage,
            date: selectedDate
          )
          commitManager.report(
            "Commit scheduled for \(Self.dateFormatter.string(from: job.executeDate)). It will also be pushed.",
            isError: false
          )
          showResult = true
        } else {
          Task {
            await commitManager.commitAndPush(
              repoPath: repoManager.targetRepoPathForCommit,
              message: commitMessage,
              date: selectedDate
            )
            showResult = true
            repoManager.commitGeneration += 1
          }
        }
      }) {
        if commitManager.isCommitting {
          ProgressView().progressViewStyle(.circular)
        } else {
          Text(isFutureCommit ? "Schedule Commit & Push" : "Commit & Push")
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(
        commitMessage.isEmpty
          || repoManager.targetRepoPathForCommit.isEmpty
          || commitManager.isCommitting
      )

      // Result
      if showResult {
        Text(commitManager.lastResult)
          .font(.caption)
          .foregroundColor(commitManager.lastResultIsError ? .red : .green)
          .padding(8)
          .background(Color.gray.opacity(0.1))
          .cornerRadius(6)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      // Pending scheduled commits for this repository
      if !pendingJobs.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Scheduled commits")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(pendingJobs) { job in
            HStack(spacing: 8) {
              Image(systemName: "clock")
                .foregroundStyle(.secondary)
              VStack(alignment: .leading, spacing: 1) {
                Text(Self.dateFormatter.string(from: job.executeDate))
                  .font(.caption)
                Text(job.message)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
              Spacer()
              Button {
                scheduler.cancel(job)
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .foregroundStyle(.secondary)
              }
              .buttonStyle(.plain)
              .help("Cancel scheduled commit")
            }
          }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
      }
    }
    .padding(20)
    .frame(width: 420)
    .onAppear {
      scheduler.refresh()
    }
    .onChange(of: repoManager.targetRepoPathForCommit) { _, _ in
      commitMessage = ""
      selectedDate = Date()
      showResult = false
      scheduler.refresh()
    }
  }
}
