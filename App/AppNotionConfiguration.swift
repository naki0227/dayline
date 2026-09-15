import Foundation

@MainActor
struct AppNotionConfiguration {
  private static let parentPageIDKey = "dayline.notion.parent-page-id"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func parentPageID() -> String {
    defaults.string(forKey: Self.parentPageIDKey) ?? ""
  }

  func save(parentPageID: String) {
    defaults.set(parentPageID, forKey: Self.parentPageIDKey)
  }
}
