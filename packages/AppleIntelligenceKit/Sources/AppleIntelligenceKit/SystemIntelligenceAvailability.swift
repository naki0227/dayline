#if canImport(FoundationModels)
  import FoundationModels
#endif

public enum SystemIntelligenceAvailability {
  public static func current() -> IntelligenceAvailability {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        switch SystemLanguageModel.default.availability {
        case .available:
          return .available
        case .unavailable(.deviceNotEligible):
          return .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
          return .unavailable(.appleIntelligenceNotEnabled)
        case .unavailable(.modelNotReady):
          return .unavailable(.modelNotReady)
        case .unavailable:
          return .unavailable(.modelNotReady)
        }
      }
    #endif
    return .unsupportedOperatingSystem
  }
}
