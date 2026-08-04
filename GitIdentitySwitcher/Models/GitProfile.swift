import Foundation

struct GitProfile: Identifiable, Codable, Equatable, Hashable {
  var id: UUID = .init()
  var label: String
  var name: String
  var email: String 
}
