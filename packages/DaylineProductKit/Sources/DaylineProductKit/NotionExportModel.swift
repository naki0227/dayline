import ContextCoreKit
import Foundation
import Observation

public enum NotionExportState: Equatable, Sendable {
  case idle
  case preparing
  case awaitingConfirmation
  case exporting
  case succeeded
  case failed
}

@MainActor
@Observable
public final class NotionExportModel {
  public private(set) var state: NotionExportState = .idle
  public private(set) var pending: PreparedNotionExport?
  public private(set) var receipt: ExternalOutputReceipt?

  private let service: NotionExportService

  public init(service: NotionExportService) {
    self.service = service
  }

  public func prepare(
    artifact: SemanticArtifactDocument,
    parentPageID: String,
    title: String
  ) {
    state = .preparing
    do {
      pending = try service.prepare(
        artifact: artifact,
        parentPageID: parentPageID,
        title: title
      )
      receipt = nil
      state = .awaitingConfirmation
    } catch {
      pending = nil
      state = .failed
    }
  }

  public func confirm() async {
    guard let pending else { return }
    state = .exporting
    do {
      receipt = try await service.execute(pending, userConfirmed: true)
      self.pending = nil
      state = .succeeded
    } catch {
      state = .failed
    }
  }

  public func cancel() {
    pending = nil
    state = .idle
  }
}
