import Foundation
import Combine

class CommitManager: ObservableObject {
  @Published var isCommitting: Bool = false
  @Published var lastResult: String = ""
  
  /// Выполняет git commit с указанной датой и временем
  func commitWithCustomDate(repoPath: String, message: String, date: Date) -> String {
    isCommitting = true
    
    // Форматируем дату в формат, который понимает Git (ISO 8601)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    formatter.timeZone = TimeZone.current // Или .current, если нужно локальное время
    let dateString = formatter.string(from: date)
    
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    task.arguments = ["commit", "-m", message]
    task.currentDirectoryURL = URL(fileURLWithPath: repoPath)
    
    // Устанавливаем переменные окружения для подмены даты
    task.environment = [
      "GIT_AUTHOR_DATE": dateString,
      "GIT_COMMITTER_DATE": dateString
    ]
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    task.standardOutput = outputPipe
    task.standardError = errorPipe
    
    do {
      try task.run()
      task.waitUntilExit()
      
      let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
      let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
      
      let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let error = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      
      lastResult = task.terminationStatus == 0 ? output : "Ошибка: \(error)"
    } catch {
      lastResult = "Ошибка запуска процесса: \(error.localizedDescription)"
    }
    
    isCommitting = false
    return lastResult
  }
  
  /// Опционально: сначала делает git add ., затем коммит
  func addAndCommit(repoPath: String, message: String, date: Date) -> String {
    let addTask = Process()
    addTask.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    addTask.arguments = ["add", "."]
    addTask.currentDirectoryURL = URL(fileURLWithPath: repoPath)
    try? addTask.run()
    addTask.waitUntilExit()
    
    return commitWithCustomDate(repoPath: repoPath, message: message, date: date)
  }
}
