import Foundation

public struct DaylineProfileCatalog: Sendable {
  public init() {}

  public func load(_ id: DaylineProfileID) throws -> DaylineAIProfile {
    guard let url = Bundle.module.url(forResource: id.rawValue, withExtension: "json") else {
      throw DaylineProfileError.resourceMissing
    }
    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      let profile = try decoder.decode(DaylineAIProfile.self, from: data)
      try profile.validate()
      guard profile.id == id else { throw DaylineProfileError.invalidDocument }
      return profile
    } catch let error as DaylineProfileError {
      throw error
    } catch {
      throw DaylineProfileError.invalidDocument
    }
  }
}
