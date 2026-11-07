import Foundation

struct GitCommandResult {
  let standardOutput: String
  let standardError: String
  let terminationStatus: Int32

  var isSuccess: Bool { terminationStatus == 0 }

  var output: String {
    standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var errorOutput: String {
    standardError.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private final class PipeCapture: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = Data()

  func store(_ data: Data) {
    lock.lock()
    storage = data
    lock.unlock()
  }

  var data: Data {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }
}

enum GitCommand {
  /// Runs git off the main thread and returns its output without blocking the UI.
  @discardableResult
  static func run(
    _ arguments: [String],
    in directory: String? = nil,
    environment: [String: String] = [:]
  ) async -> GitCommandResult {
    await withCheckedContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
      process.arguments = arguments
      if let directory {
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
      }
      if !environment.isEmpty {
        var merged = ProcessInfo.processInfo.environment
        for (key, value) in environment {
          merged[key] = value
        }
        process.environment = merged
      }

      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      let readers = DispatchGroup()
      let outputCapture = PipeCapture()
      let errorCapture = PipeCapture()

      readers.enter()
      DispatchQueue.global(qos: .userInitiated).async {
        outputCapture.store(outputPipe.fileHandleForReading.readDataToEndOfFile())
        readers.leave()
      }

      readers.enter()
      DispatchQueue.global(qos: .userInitiated).async {
        errorCapture.store(errorPipe.fileHandleForReading.readDataToEndOfFile())
        readers.leave()
      }

      process.terminationHandler = { finishedProcess in
        readers.wait()
        continuation.resume(
          returning: GitCommandResult(
            standardOutput: String(data: outputCapture.data, encoding: .utf8) ?? "",
            standardError: String(data: errorCapture.data, encoding: .utf8) ?? "",
            terminationStatus: finishedProcess.terminationStatus
          )
        )
      }

      do {
        try process.run()
        // The child process has its own copies of the descriptors now.
        try? outputPipe.fileHandleForWriting.close()
        try? errorPipe.fileHandleForWriting.close()
      } catch {
        try? outputPipe.fileHandleForWriting.close()
        try? errorPipe.fileHandleForWriting.close()
        continuation.resume(
          returning: GitCommandResult(
            standardOutput: "",
            standardError: error.localizedDescription,
            terminationStatus: -1
          )
        )
      }
    }
  }
}
