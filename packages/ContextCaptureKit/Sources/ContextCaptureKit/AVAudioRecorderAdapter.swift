#if os(iOS)
  import AVFAudio
  import Foundation
  import OSLog

  @MainActor
  private final class AppleRecordingAudioSession: RecordingAudioSessionControlling {
    private let session: AVAudioSession
    private let logger: Logger

    init(
      session: AVAudioSession = .sharedInstance(),
      logger: Logger = Logger(subsystem: "app.dayline", category: "AudioSession")
    ) {
      self.session = session
      self.logger = logger
    }

    func configureForRecording() throws {
      do {
        try session.setCategory(
          .record,
          mode: .default,
          options: [.allowBluetoothHFP]
        )
      } catch {
        log(error, operation: "configure")
        throw error
      }
    }

    func activate() throws {
      do {
        try session.setActive(true)
      } catch {
        log(error, operation: "activate")
        throw error
      }
    }

    func deactivate() {
      do {
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
      } catch {
        log(error, operation: "deactivate")
      }
    }

    private func log(_ error: Error, operation: String) {
      let error = error as NSError
      logger.error(
        "Audio session \(operation, privacy: .public): domain=\(error.domain, privacy: .public) code=\(error.code)"
      )
    }
  }

  @MainActor
  public final class AVAudioRecorderAdapter: NSObject, AudioRecording {
    private var recorder: AVAudioRecorder?
    private var interruptionHandler: (@MainActor @Sendable (AudioInterruption) async -> Void)?
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let audioSession: RecordingAudioSessionLifecycle
    private let logger = Logger(subsystem: "app.dayline", category: "AudioRecorder")

    public init(
      fileManager: FileManager = .default,
      baseDirectory: URL? = nil
    ) {
      self.fileManager = fileManager
      self.baseDirectory = baseDirectory ?? Self.defaultBaseDirectory(fileManager: fileManager)
      self.audioSession = RecordingAudioSessionLifecycle(session: AppleRecordingAudioSession())
      super.init()
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleInterruption),
        name: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance()
      )
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    public func startChunk() async throws -> URL {
      guard await AVAudioApplication.requestRecordPermission() else {
        throw CaptureFailure.microphonePermissionDenied
      }
      try audioSession.prepare()
      do {
        let destination = try makeDestination()
        let recorder = try AVAudioRecorder(
          url: destination,
          settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
          ]
        )
        guard recorder.record() else {
          throw CaptureFailure.recordingFailed
        }
        self.recorder = recorder
        return destination
      } catch let failure as CaptureFailure {
        audioSession.deactivate()
        throw failure
      } catch {
        let error = error as NSError
        logger.error(
          "Audio recorder start: domain=\(error.domain, privacy: .public) code=\(error.code)"
        )
        audioSession.deactivate()
        throw CaptureFailure.recordingFailed
      }
    }

    public func stopChunk() async {
      recorder?.stop()
      recorder = nil
      audioSession.deactivate()
    }

    public func setInterruptionHandler(
      _ handler: @escaping @MainActor @Sendable (AudioInterruption) async -> Void
    ) {
      interruptionHandler = handler
    }

    @objc
    private func handleInterruption(_ notification: Notification) {
      guard
        let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        let type = AVAudioSession.InterruptionType(rawValue: rawType)
      else { return }

      let interruption: AudioInterruption
      switch type {
      case .began:
        interruption = .began
      case .ended:
        let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
        interruption = .ended(shouldResume: options.contains(.shouldResume))
      @unknown default:
        return
      }
      guard let interruptionHandler else { return }
      Task { @MainActor in
        await interruptionHandler(interruption)
      }
    }

    private func makeDestination() throws -> URL {
      let calendar = Calendar(identifier: .gregorian)
      let components = calendar.dateComponents([.year, .month, .day], from: Date())
      guard let year = components.year, let month = components.month, let day = components.day
      else {
        throw CaptureFailure.storageUnavailable
      }
      let dayDirectory =
        baseDirectory
        .appending(
          path: String(format: "%04d-%02d-%02d", year, month, day), directoryHint: .isDirectory)
      do {
        try fileManager.createDirectory(
          at: dayDirectory,
          withIntermediateDirectories: true
        )
      } catch {
        throw CaptureFailure.storageUnavailable
      }
      return dayDirectory.appending(path: "\(UUID().uuidString.lowercased()).m4a")
    }

    private static func defaultBaseDirectory(fileManager: FileManager) -> URL {
      let applicationSupport =
        fileManager.urls(
          for: .applicationSupportDirectory,
          in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
      return applicationSupport.appending(path: "audio", directoryHint: .isDirectory)
    }
  }
#endif
