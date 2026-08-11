import SwiftUI

struct ProfileListView: View {
  
  // MARK: - Properties
  
  @EnvironmentObject var manager: ProfileManager
  var onAddProfile: (() -> Void)?
  var onEditProfile: ((GitProfile) -> Void)?
  
  // MARK: - Body
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Current(global): \(manager.activeName)")
        .font(.caption)
        .foregroundColor(.secondary)
      Text(manager.activeEmail)
        .font(.caption2)
        .foregroundColor(.secondary)
      
      Divider()
      
      ForEach(manager.profiles) { profile in
        Button {
          manager.switchGlobalTo(profile)
        } label: {
          HStack {
            Text(profile.label)
            Spacer()
            if profile.email == manager.activeEmail {
              Image(systemName: "checkmark")
            }
          }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .contextMenu {
          Button("Edit") { onEditProfile?(profile) }
          Button("Delete", role: .destructive) { manager.deleteProfile(profile) }
        }
      }
      
      Divider()
      
      Button("Add profile...") {
        onAddProfile?()
      }
      
      Button("Logout") {
        NSApp.terminate(nil)
      }
    }
    .padding(10)
  }
}
