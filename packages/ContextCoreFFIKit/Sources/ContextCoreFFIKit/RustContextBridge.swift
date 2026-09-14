import ContextCoreFFIGenerated
import ContextCoreKit
import Foundation

public enum RustContextBridgeError: Error, Equatable {
  case invalidUTF8
  case invalidContract
  case rustFailure
}

public struct RustContextBridge: Sendable {
  public init() {}

  public func buildContext(request: Data) throws -> ContextBundleDocument {
    guard let requestJSON = String(data: request, encoding: .utf8) else {
      throw RustContextBridgeError.invalidUTF8
    }
    do {
      let response = try buildContextBundle(requestJson: requestJSON)
      guard let data = response.data(using: .utf8) else {
        throw RustContextBridgeError.invalidUTF8
      }
      let bundle = try ContractCodec.decode(ContextBundleDocument.self, from: data)
      try bundle.validateVersion()
      return bundle
    } catch let error as RustContextBridgeError {
      throw error
    } catch is DecodingError {
      throw RustContextBridgeError.invalidContract
    } catch {
      throw RustContextBridgeError.rustFailure
    }
  }

  public func buildStoredContext(
    databaseURL: URL,
    request: Data
  ) throws -> ContextBundleDocument {
    guard let requestJSON = String(data: request, encoding: .utf8) else {
      throw RustContextBridgeError.invalidUTF8
    }
    do {
      let response = try buildStoredContextBundle(
        databasePath: databaseURL.path,
        requestJson: requestJSON
      )
      guard let data = response.data(using: .utf8) else {
        throw RustContextBridgeError.invalidUTF8
      }
      let bundle = try ContractCodec.decode(ContextBundleDocument.self, from: data)
      try bundle.validateVersion()
      return bundle
    } catch let error as RustContextBridgeError {
      throw error
    } catch is DecodingError {
      throw RustContextBridgeError.invalidContract
    } catch {
      throw RustContextBridgeError.rustFailure
    }
  }

  public func persistEvent(databaseURL: URL, event: Data) throws -> Data {
    try persist(
      databaseURL: databaseURL,
      document: event,
      operation: persistContextEvent
    )
  }

  public func shrinkContext(
    _ context: ContextBundleDocument,
    maximumUnits: UInt64
  ) throws -> ContextBundleDocument {
    do {
      let document = try ContractCodec.encode(context)
      guard let json = String(data: document, encoding: .utf8) else {
        throw RustContextBridgeError.invalidUTF8
      }
      let response = try shrinkContextBundle(bundleJson: json, maximumUnits: maximumUnits)
      guard let data = response.data(using: .utf8) else {
        throw RustContextBridgeError.invalidUTF8
      }
      let bundle = try ContractCodec.decode(ContextBundleDocument.self, from: data)
      try bundle.validateVersion()
      return bundle
    } catch let error as RustContextBridgeError {
      throw error
    } catch is DecodingError {
      throw RustContextBridgeError.invalidContract
    } catch {
      throw RustContextBridgeError.rustFailure
    }
  }

  public func persistArtifact(
    databaseURL: URL,
    artifact: SemanticArtifactDocument
  ) throws -> SemanticArtifactDocument {
    let document = try ContractCodec.encode(artifact)
    let persisted = try persist(
      databaseURL: databaseURL,
      document: document,
      operation: persistSemanticArtifact
    )
    do {
      let decoded = try ContractCodec.decode(SemanticArtifactDocument.self, from: persisted)
      try decoded.validateVersion()
      return decoded
    } catch {
      throw RustContextBridgeError.invalidContract
    }
  }

  private func persist(
    databaseURL: URL,
    document: Data,
    operation: (String, String) throws -> String
  ) throws -> Data {
    guard let documentJSON = String(data: document, encoding: .utf8) else {
      throw RustContextBridgeError.invalidUTF8
    }
    do {
      let response = try operation(databaseURL.path, documentJSON)
      guard let data = response.data(using: .utf8) else {
        throw RustContextBridgeError.invalidUTF8
      }
      return data
    } catch let error as RustContextBridgeError {
      throw error
    } catch {
      throw RustContextBridgeError.rustFailure
    }
  }
}
