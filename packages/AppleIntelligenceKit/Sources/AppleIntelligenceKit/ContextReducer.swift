import ContextCoreKit

public struct ContextReducer: Sendable {
  private let operation:
    @Sendable (ContextBundleDocument, UInt64) async throws -> ContextBundleDocument

  public init(
    operation:
      @escaping @Sendable (
        ContextBundleDocument,
        UInt64
      ) async throws -> ContextBundleDocument
  ) {
    self.operation = operation
  }

  public func reduce(
    _ context: ContextBundleDocument,
    maximumUnits: UInt64
  ) async throws -> ContextBundleDocument {
    try await operation(context, maximumUnits)
  }
}

enum ContextWindowPlanner {
  static func measuredTarget(
    currentUnits: UInt64,
    measuredTokens: Int,
    allowedTokens: Int
  ) -> UInt64? {
    guard currentUnits > 1, measuredTokens > allowedTokens, allowedTokens > 0 else {
      return nil
    }
    let ratio = (Double(allowedTokens) / Double(measuredTokens)) * 0.9
    let proposed = UInt64((Double(currentUnits) * ratio).rounded(.down))
    return min(max(1, proposed), currentUnits - 1)
  }

  static func fallbackTarget(currentUnits: UInt64) -> UInt64? {
    guard currentUnits > 1 else { return nil }
    let proposed = (currentUnits / 4) * 3 + ((currentUnits % 4) * 3) / 4
    return min(max(1, proposed), currentUnits - 1)
  }
}
