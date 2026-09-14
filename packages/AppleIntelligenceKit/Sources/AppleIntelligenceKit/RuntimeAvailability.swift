public enum IntelligenceUnavailableReason: Equatable, Sendable {
  case deviceNotEligible
  case appleIntelligenceNotEnabled
  case modelNotReady
}

public enum IntelligenceAvailability: Equatable, Sendable {
  case available
  case unsupportedOperatingSystem
  case unavailable(IntelligenceUnavailableReason)
}

public enum AppleIntelligenceRuntimeError: Error, Equatable {
  case unsupportedOperatingSystem
  case unavailable(IntelligenceUnavailableReason)
  case invalidContract
  case emptyContext
  case contextWindowExceeded
  case reductionFailed
  case assetsUnavailable
  case guardrailViolation
  case unsupportedLanguage
  case decodingFailure
  case rateLimited
  case concurrentRequest
  case refused
  case generationFailed
}
