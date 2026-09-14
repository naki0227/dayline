import Foundation

public enum ContractCodecError: Error, Equatable {
  case unsupportedSchemaVersion(UInt32)
}

public enum ContractCodec {
  public static func decode<T: Decodable>(
    _ type: T.Type,
    from data: Data
  ) throws -> T {
    try decoder.decode(type, from: data)
  }

  public static func encode<T: Encodable>(_ value: T) throws -> Data {
    try encoder.encode(value)
  }

  public static func validate(schemaVersion: UInt32) throws {
    guard schemaVersion == ContextCoreKit.schemaVersion else {
      throw ContractCodecError.unsupportedSchemaVersion(schemaVersion)
    }
  }

  private static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

  private static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}
