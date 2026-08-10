import SwiftUI

struct ProfileEditWindow: View {
  @EnvironmentObject var manager: ProfileManager
  let profileID: UUID?
  
  var body: some View {
    ProfileEditView(profile: manager.profiles.first(where: { $0.id == profileID })) { profile in
      if manager.profiles.contains(where: { $0.id == profile.id }) {
        manager.updateProfile(profile)
      } else {
        manager.addProfile(profile)
      }
    }
    .onAppear {
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}
