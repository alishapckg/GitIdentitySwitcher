import SwiftUI

struct ProfileEditView: View {
  @Environment(\.dismiss) var dismiss
  
  @State private var label: String
  @State private var name: String
  @State private var email: String
  
  let existingID: UUID?
  let onSave: (GitProfile) -> Void
  
  init(profile: GitProfile?, onSave: @escaping (GitProfile) -> Void) {
    _label = State(initialValue: profile?.label ?? "")
    _name = State(initialValue: profile?.name ?? "")
    _email = State(initialValue: profile?.email ?? "")
    self.existingID = profile?.id
    self.onSave = onSave
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(existingID == nil ? "New profile" : "Edit profile")
        .font(.headline)
      
      TextField("Title (for ex., work", text: $label)
      TextField("Git name", text: $name)
      TextField("Git email", text: $email)
        .textContentType(.emailAddress)
      
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }
        Button("Save") {
          let profile = GitProfile(
            id: existingID ?? UUID(),
            label: label,
            name: name,
            email: email
          )
          onSave(profile)
          dismiss()
        }
        .disabled(label.isEmpty || name.isEmpty || email.isEmpty)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 320)
  }
}
