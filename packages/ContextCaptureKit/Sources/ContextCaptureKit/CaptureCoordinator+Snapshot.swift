extension CaptureCoordinator {
  public var snapshot: CaptureSnapshot {
    CaptureSnapshot(
      daily: dailyState,
      audio: audioState,
      activeFileURL: activeFileURL,
      startedAt: startedAt,
      lastFailure: lastFailure
    )
  }
}
