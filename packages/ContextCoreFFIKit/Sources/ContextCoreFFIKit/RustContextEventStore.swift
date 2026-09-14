import ContextCoreKit
import Foundation

public actor RustContextEventStore: ContextEventPersisting {
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
    } catch let error as RustContextBridgeError {
      throw error
    } catch is DecodingError {
      throw RustContextBridgeError.invalidContract
    } catch is ContractCodecError {
      throw RustContextBridgeError.invalidContract
    } catch {
      throw RustContextBridgeError.rustFailure
    }
  }
}
