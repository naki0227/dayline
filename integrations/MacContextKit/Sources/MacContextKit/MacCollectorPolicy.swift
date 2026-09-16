import Foundation

public enum MacContextSource: String, Codable, CaseIterable, Sendable {
  case shell
  case browser
}

public struct MacCollectorPolicy: Codable, Equatable, Sendable {
  public let enabledSources: Set<MacContextSource>

  public init(enabledSources: Set<MacContextSource> = []) {
    self.enabledSources = enabledSources
  }

  public func isEnabled(_ source: MacContextSource) -> Bool {
    enabledSources.contains(source)
  }

  public func setting(_ source: MacContextSource, enabled: Bool) -> MacCollectorPolicy {
    var updated = enabledSources
    if enabled { updated.insert(source) } else { updated.remove(source) }
    return MacCollectorPolicy(enabledSources: updated)
  }
}

public actor MacCollectorSettingsStore {
  private let fileURL: URL
  private let fileManager: FileManager

  public init(fileURL: URL, fileManager: FileManager = .default) {
    self.fileURL = fileURL
    self.fileManager = fileManager
  }

  public func load() throws -> MacCollectorPolicy {
    guard fileManager.fileExists(atPath: fileURL.path) else { return MacCollectorPolicy() }
    return try JSONDecoder().decode(
      MacCollectorPolicy.self,
      from: Data(contentsOf: fileURL, options: .mappedIfSafe)
    )
  }

  public func save(_ policy: MacCollectorPolicy) throws {
    let directory = fileURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(policy)
    try data.write(to: fileURL, options: .atomic)
    try fileManager.setAttributes(
      [.posixPermissions: 0o600],
      ofItemAtPath: fileURL.path
    )
  }
}
