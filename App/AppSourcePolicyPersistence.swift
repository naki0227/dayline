import DaylineProductKit
import Foundation

@MainActor
struct AppSourcePolicyPersistence {
  private static let enabledSourcesKey = "dayline.privacy.enabled-sources-v1"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> DaylineSourcePolicy {
    guard let values = defaults.stringArray(forKey: Self.enabledSourcesKey) else {
      return .localDefault
    }
    let sources = values.compactMap(DaylineContextSource.init(rawValue:))
    return DaylineSourcePolicy(enabledSources: sources)
  }

  func save(_ policy: DaylineSourcePolicy) {
    defaults.set(policy.enabledSources.map(\.rawValue), forKey: Self.enabledSourcesKey)
  }
}
