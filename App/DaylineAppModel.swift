import ContextCaptureKit
import DaylineProductKit
import Observation

@MainActor
@Observable
final class DaylineAppModel {
  let capture: CaptureCoordinator
  let dailySummary: DailySummaryModel
  let liveCapture: LiveMeetingCoordinator
  let liveMeeting: LiveMeetingModel

  init(environment: AppEnvironment) {
    capture = environment.capture
    dailySummary = environment.dailySummary
    liveCapture = environment.liveCapture
    liveMeeting = environment.liveMeeting
  }

  func toggleDailyCapture() async {
    if capture.dailyState == .stopped, liveCapture.state == .running {
      await stopLiveMeeting()
    }
    await capture.toggle()
  }

  func toggleLiveMeeting() async {
    if liveCapture.state == .running {
      await stopLiveMeeting()
      return
    }
    if capture.dailyState == .running {
      await capture.stop()
    }
    await liveCapture.start()
    guard
      liveCapture.state == .running,
      let sessionID = liveCapture.sessionID,
      let startedAt = liveCapture.startedAt
    else { return }
    liveMeeting.begin(sessionID: sessionID, startedAt: startedAt)
  }

  private func stopLiveMeeting() async {
    await liveCapture.stop()
    await liveMeeting.end()
  }
}
