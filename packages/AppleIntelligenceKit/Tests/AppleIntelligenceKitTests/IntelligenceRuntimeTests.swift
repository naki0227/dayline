import Testing

@testable import AppleIntelligenceKit

private struct RuntimeStub: IntelligenceRuntime {}

@Test
func runtimeBoundaryAcceptsIndependentImplementations() {
  let runtime: any IntelligenceRuntime = RuntimeStub()

  #expect(runtime is RuntimeStub)
}
