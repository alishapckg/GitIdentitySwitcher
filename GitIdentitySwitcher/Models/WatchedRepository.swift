import Foundation

struct WatchedRepository: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var path: String
  var expectedProfileID: UUID
}
