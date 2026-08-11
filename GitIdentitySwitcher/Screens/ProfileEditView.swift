import SwiftUI

struct ProfileEditView: View {
  
  // MARK: - Properties
  
  @State private var label: String
  @State private var name: String
  @State private var email: String
  
  let existingID: UUID?
  let onSave: (GitProfile) -> Void
  var onCancel: (() -> Void)?
  
  
  // MARK: - Init
  
  init(profile: GitProfile?, onSave: @escaping (GitProfile) -> Void, onCancel: (() -> Void)? = nil) {
    _label = State(initialValue: profile?.label ?? "")
    _name = State(initialValue: profile?.name ?? "")
    _email = State(initialValue: profile?.email ?? "")
    self.existingID = profile?.id
    self.onSave = onSave
    self.onCancel = onCancel
  }
  
  // MARK: - Body
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(existingID == nil ? "New profile" : "Edit profile")
        .font(.headline)
      
      TextField("Title (for ex., work)", text: $label)
      TextField("Git name", text: $name)
      TextField("Git email", text: $email)
        .textContentType(.emailAddress)
      
      HStack {
        Spacer()
        Button("Cancel") {
          onCancel?()
        }
        Button("Save") {
          let profile = GitProfile(
            id: existingID ?? UUID(),
            label: label,
            name: name,
            email: email
          )
          onSave(profile)
        }
        .disabled(label.isEmpty || name.isEmpty || email.isEmpty)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
  }
}
