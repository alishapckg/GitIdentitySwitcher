import SwiftUI

struct CustomCommitView: View {
  // Получаем менеджер, в который RepoRowView записал путь
  @EnvironmentObject var repoManager: RepoManager
  @StateObject private var commitManager = CommitManager()
  
  @State private var commitMessage: String = ""
  @State private var selectedDate: Date = Date()
  @State private var showResult: Bool = false
  
  var body: some View {
    VStack(spacing: 20) {
      Text("Кастомный коммит")
        .font(.title2)
        .fontWeight(.semibold)
      
      // Путь к репозиторию (берется автоматически из repoManager)
      VStack(alignment: .leading, spacing: 6) {
        Text("Репозиторий:")
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
      
      // Сообщение коммита
      VStack(alignment: .leading, spacing: 6) {
        Text("Сообщение коммита:")
          .font(.caption)
          .foregroundColor(.secondary)
        TextField("Введите сообщение...", text: $commitMessage)
          .textFieldStyle(.roundedBorder)
      }
      
      // Красивый графический календарь
      VStack(alignment: .leading, spacing: 8) {
        Text("Дата и время коммита:")
          .font(.caption)
          .foregroundColor(.secondary)
        
        DatePicker(
          "",
          selection: $selectedDate,
          displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
      }
      
      // Кнопка выполнения
      Button(action: {
        guard !commitMessage.isEmpty else { return }
        let result = commitManager.addAndCommit(
          repoPath: repoManager.targetRepoPathForCommit,
          message: commitMessage,
          date: selectedDate
        )
        showResult = true
      }) {
        if commitManager.isCommitting {
          ProgressView().progressViewStyle(.circular)
        } else {
          Text("Скоммитить").frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(commitMessage.isEmpty || commitManager.isCommitting)
      
      // Результат
      if showResult {
        Text(commitManager.lastResult)
          .font(.caption)
          .foregroundColor(commitManager.lastResult.hasPrefix("Ошибка") ? .red : .green)
          .padding(8)
          .background(Color.gray.opacity(0.1))
          .cornerRadius(6)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(24)
    .frame(width: 420) // Ширина для красивого отображения календаря
  }
}
