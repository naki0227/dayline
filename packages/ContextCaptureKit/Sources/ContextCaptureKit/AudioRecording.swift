import Foundation

public enum AudioInterruption: Equatable, Sendable {
  case began
  case ended(shouldResume: Bool)
}

@MainActor
public protocol AudioRecording: AnyObject {
  func startChunk() async throws -> URL
  func stopChunk() async
  func setInterruptionHandler(
    _ handler: @escaping @MainActor @Sendable (AudioInterruption) async -> Void
  )
}

extension AudioRecording {
  public func setInterruptionHandler(
    _: @escaping @MainActor @Sendable (AudioInterruption) async -> Void
  ) {}
}
