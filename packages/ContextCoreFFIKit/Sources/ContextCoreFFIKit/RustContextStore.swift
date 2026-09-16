import ContextCoreKit
import Foundation

public actor RustContextStore: ContextEventPersisting {
  private let databaseURL: URL
  private let bridge: RustContextBridge

  public init(
    databaseURL: URL,
    bridge: RustContextBridge = RustContextBridge()
  ) {
    self.databaseURL = databaseURL
    self.bridge = bridge
  }

  public func persist(
    _ event: TextContextEventDocument
  ) throws -> TextContextEventDocument {
    do {
      try event.validateVersion()
      let document = try ContractCodec.encode(event)
      let persisted = try bridge.persistEvent(databaseURL: databaseURL, event: document)
      let decoded = try ContractCodec.decode(TextContextEventDocument.self, from: persisted)
      try decoded.validateVersion()
      return decoded
    } catch {
      throw map(error)
    }
  }

  public func persistEventData(_ event: Data) throws -> Data {
    do {
      return try bridge.persistEvent(databaseURL: databaseURL, event: event)
    } catch {
      throw map(error)
    }
  }

  public func buildStoredContext(
    _ request: StoredContextRequestDocument
  ) throws -> ContextBundleDocument {
    do {
      try request.validateVersion()
      let document = try ContractCodec.encode(request)
      return try bridge.buildStoredContext(databaseURL: databaseURL, request: document)
    } catch {
      throw map(error)
    }
  }

  public func persist(
    _ artifact: SemanticArtifactDocument
  ) throws -> SemanticArtifactDocument {
    do {
      try artifact.validateVersion()
      return try bridge.persistArtifact(databaseURL: databaseURL, artifact: artifact)
    } catch {
      throw map(error)
    }
  }

  private func map(_ error: any Error) -> RustContextBridgeError {
    if let bridgeError = error as? RustContextBridgeError { return bridgeError }
    if error is DecodingError || error is ContractCodecError {
      return .invalidContract
    }
    return .rustFailure
  }
}

extension RustContextStore: StoredContextBuilding {}
extension RustContextStore: SemanticArtifactPersisting {}
extension RustContextStore: ContextEventDataPersisting {}
