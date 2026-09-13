import Testing

@testable import ContextCoreKit

@Test
func schemaVersionStartsAtOne() {
  #expect(ContextCoreKit.schemaVersion == 1)
}
