import Foundation

public struct TranscriptBuffer: Equatable, Sendable {
  public private(set) var finalized: [TranscriptionSegment] = []
  public private(set) var volatile: TranscriptionSegment?
  private var finalizedKeys: Set<String> = []

  public init() {}

  @discardableResult
  public mutating func ingest(
    _ segment: TranscriptionSegment,
    sourceID: String = "direct"
  ) -> Bool {
    guard !segment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }
    if !segment.isFinal {
      volatile = segment
      return false
    }

    volatile = nil
    let key = "\(sourceID)|\(segment.startTime)|\(segment.duration)|\(segment.text)"
    guard finalizedKeys.insert(key).inserted else { return false }
    finalized.append(segment)
    return true
  }
}
