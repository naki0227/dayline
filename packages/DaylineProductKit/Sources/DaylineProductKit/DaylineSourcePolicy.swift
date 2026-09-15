import ContextCoreKit

public enum DaylineContextSource: String, CaseIterable, Codable, Sendable {
  case audio
  case browser
  case shell
  case calendar
  case github
  case notion
}

public struct DaylineSourcePolicy: Codable, Equatable, Sendable {
  public static let localDefault = DaylineSourcePolicy(enabledSources: [.audio])
  public static let allEnabled = DaylineSourcePolicy(enabledSources: DaylineContextSource.allCases)

  private let enabled: Set<DaylineContextSource>

  public init(enabledSources: some Sequence<DaylineContextSource>) {
    enabled = Set(enabledSources)
  }

  public var enabledSources: [DaylineContextSource] {
    DaylineContextSource.allCases.filter(enabled.contains)
  }

  public var contextSources: [ContextSourceDocument] {
    enabledSources.map { ContextSourceDocument(type: $0.rawValue) }
  }

  public func isEnabled(_ source: DaylineContextSource) -> Bool {
    enabled.contains(source)
  }

  public func setting(
    _ source: DaylineContextSource,
    enabled isEnabled: Bool
  ) -> DaylineSourcePolicy {
    var next = enabled
    if isEnabled {
      next.insert(source)
    } else {
      next.remove(source)
    }
    return DaylineSourcePolicy(enabledSources: next)
  }
}

public protocol DaylineSourcePolicyReading: Sendable {
  func currentPolicy() async -> DaylineSourcePolicy
}

public actor DaylineSourcePolicyStore: DaylineSourcePolicyReading {
  private var policy: DaylineSourcePolicy

  public init(policy: DaylineSourcePolicy) {
    self.policy = policy
  }

  public func currentPolicy() -> DaylineSourcePolicy {
    policy
  }

  public func replace(with policy: DaylineSourcePolicy) {
    self.policy = policy
  }
}
