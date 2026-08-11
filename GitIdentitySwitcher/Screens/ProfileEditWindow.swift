import SwiftUI

struct ProfileEditWindow: View {
  @EnvironmentObject var manager: ProfileManager
  @Environment(\.dismiss) private var dismiss
  let profileID: UUID?
  
  var body: some View {
    ProfileEditView(
      profile: manager.profiles.first(where: { $0.id == profileID }),
      onSave: { profile in
        if manager.profiles.contains(where: { $0.id == profile.id }) {
          manager.updateProfile(profile)
        } else {
          manager.addProfile(profile)
        }
        dismiss()
      },
      onCancel: {
        dismiss()
      }
    )
    .onAppear {
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}
