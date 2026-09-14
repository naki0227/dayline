#if os(iOS)
  import Foundation
  import Speech

  @available(iOS 26.0, *)
  enum AppleSpeechSupport {
    static func makeTranscriber(
      locale: Locale,
      preset: SpeechTranscriber.Preset
    ) async throws -> (SpeechTranscriber, Locale) {
      try await requestPermission()
      guard SpeechTranscriber.isAvailable else {
        throw TranscriptionFailure.assetsUnavailable
      }
      guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
      else {
        throw TranscriptionFailure.unsupportedLocale
      }
      let transcriber = SpeechTranscriber(locale: supportedLocale, preset: preset)
      try await prepareAssets(for: transcriber)
      return (transcriber, supportedLocale)
    }

    private static func requestPermission() async throws {
      let status = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
          continuation.resume(returning: status)
        }
      }
      guard status == .authorized else {
        throw TranscriptionFailure.speechPermissionDenied
      }
    }

    private static func prepareAssets(for transcriber: SpeechTranscriber) async throws {
      let modules: [any SpeechModule] = [transcriber]
      let status = await AssetInventory.status(forModules: modules)
      switch status {
      case .installed:
        return
      case .supported, .downloading:
        do {
          if let request = try await AssetInventory.assetInstallationRequest(
            supporting: modules
          ) {
            try await request.downloadAndInstall()
          }
        } catch {
          throw TranscriptionFailure.assetsUnavailable
        }
      case .unsupported:
        throw TranscriptionFailure.assetsUnavailable
      @unknown default:
        throw TranscriptionFailure.assetsUnavailable
      }
    }
  }
#endif
