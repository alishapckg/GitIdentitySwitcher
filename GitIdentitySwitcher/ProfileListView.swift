import SwiftUI

struct ProfileListView: View {
  @EnvironmentObject var manager: ProfileManager
  @State private var showingAddSheet = false
  @State private var editingProfile: GitProfile?
  
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
          Button("Edit") { editingProfile = profile }
          Button("Delete", role: .destructive) { manager.deleteProfile(profile) }
        }
      }
      
      Divider()
      
      Button("Add profile...") {
        showingAddSheet = true
      }
      
      Button("Logout") {
        NSApp.terminate(nil)
      }
    }
    .padding(10)
    .sheet(isPresented: $showingAddSheet) {
      ProfileEditView(profile: nil) { newProfile in
        manager.addProfile(newProfile)
      }
    }
    .sheet(item: $editingProfile) { profile in
      ProfileEditView(profile: profile) { updated in
        manager.updateProfile(updated)
      }
    }
  }
}
