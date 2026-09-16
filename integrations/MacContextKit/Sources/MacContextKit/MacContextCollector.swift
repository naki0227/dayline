import ContextCoreKit
import Foundation

public actor MacContextCollector {
  private let settings: MacCollectorSettingsStore
  private let persistence: any ContextEventDataPersisting
  private let factory: MacContextEventFactory

  public init(
    settings: MacCollectorSettingsStore,
    persistence: any ContextEventDataPersisting,
    factory: MacContextEventFactory
  ) {
    self.settings = settings
    self.persistence = persistence
    self.factory = factory
  }

  @discardableResult
  public func collectShell(_ observation: ShellCommandObservation) async throws -> Bool {
    let policy = try await loadPolicy()
    guard policy.isEnabled(.shell) else { return false }
    let document = try factory.shell(observation)
    do {
      _ = try await persistence.persistEventData(document)
      return true
    } catch {
      throw MacContextCollectionFailure.persistenceFailed
    }
  }

  public func collectChrome(_ observations: [ChromeVisitObservation]) async throws -> Int {
    let policy = try await loadPolicy()
    guard policy.isEnabled(.browser) else { return 0 }
    var persisted = 0
    for observation in observations {
      do {
        let document = try factory.browser(observation)
        _ = try await persistence.persistEventData(document)
        persisted += 1
      } catch MacContextCollectionFailure.invalidObservation {
        continue
      } catch {
        throw MacContextCollectionFailure.persistenceFailed
      }
    }
    return persisted
  }

  private func loadPolicy() async throws -> MacCollectorPolicy {
    do {
      return try await settings.load()
    } catch {
      throw MacContextCollectionFailure.settingsUnavailable
    }
  }
}
