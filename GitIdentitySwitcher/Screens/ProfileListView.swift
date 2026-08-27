import SwiftUI

struct ProfileListView: View {
  
  // MARK: - Properties
  
  @EnvironmentObject var manager: ProfileManager
  var onAddProfile: (() -> Void)?
  var onEditProfile: ((GitProfile) -> Void)?
  
  // MARK: - Body
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("Current(global): \(manager.activeName)")
          .font(.caption)
          .foregroundColor(.secondary)
        if manager.isSwitching {
          ProgressView()
            .controlSize(.small)
        }
      }
      Text(manager.activeEmail)
        .font(.caption2)
        .foregroundColor(.secondary)
      
      Divider()
      
      ForEach(manager.profiles) { profile in
        Button {
          manager.switchGlobalTo(profile)
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(profile.label)
              Text(profile.email)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            if profile.email.lowercased() == manager.activeEmail.lowercased() {
              Image(systemName: "checkmark")
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .disabled(manager.isSwitching)
        .contextMenu {
          Button("Edit") { onEditProfile?(profile) }
          Button("Delete", role: .destructive) { manager.deleteProfile(profile) }
        }
      }
      
      Divider()
      
      Button("Add profile...") {
        onAddProfile?()
      }
      
      Button("Quit") {
        NSApp.terminate(nil)
      }
    }
    .padding(10)
  }
}
