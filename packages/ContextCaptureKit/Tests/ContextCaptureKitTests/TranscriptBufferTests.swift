import Testing

@testable import ContextCaptureKit

@Test
func keepsVolatileTextSeparateFromFinalizedEvidence() {
  var buffer = TranscriptBuffer()
  let draft = segment(text: "draft", isFinal: false)
  let final = segment(text: "final", isFinal: true)

  let acceptedDraft = buffer.ingest(draft)
  #expect(!acceptedDraft)
  #expect(buffer.volatile == draft)
  #expect(buffer.finalized.isEmpty)

  let acceptedFinal = buffer.ingest(final)
  #expect(acceptedFinal)
  #expect(buffer.volatile == nil)
  #expect(buffer.finalized == [final])
}

@Test
func ignoresBlankAndDuplicateFinalSegments() {
  var buffer = TranscriptBuffer()
  let final = segment(text: "decision", isFinal: true)

  let acceptedBlank = buffer.ingest(segment(text: "  ", isFinal: true))
  let acceptedFirst = buffer.ingest(final)
  let acceptedDuplicate = buffer.ingest(final)
  #expect(!acceptedBlank)
  #expect(acceptedFirst)
  #expect(!acceptedDuplicate)
  #expect(buffer.finalized == [final])
}

private func segment(text: String, isFinal: Bool) -> TranscriptionSegment {
  TranscriptionSegment(
    text: text,
    localeIdentifier: "ja-JP",
    startTime: 2,
    duration: 1,
    isFinal: isFinal
  )
}
