import ContextCaptureKit
import DaylineProductKit
import NotionKit
import Observation

@MainActor
@Observable
final class DaylineAppModel {
  let capture: CaptureCoordinator
  let dailySummary: DailySummaryModel
  let liveCapture: LiveMeetingCoordinator
  let liveMeeting: LiveMeetingModel
  let notionExport: NotionExportModel
  let notionConnection: NotionConnectionModel
  let notionConfiguration: AppNotionConfiguration
  private(set) var sourcePolicy: DaylineSourcePolicy

  private let sourcePolicyStore: DaylineSourcePolicyStore
  private let sourcePolicyPersistence: AppSourcePolicyPersistence

  init(environment: AppEnvironment) {
    capture = environment.capture
    dailySummary = environment.dailySummary
    liveCapture = environment.liveCapture
    liveMeeting = environment.liveMeeting
    notionExport = environment.notionExport
    notionConnection = environment.notionConnection
    notionConfiguration = environment.notionConfiguration
    sourcePolicy = environment.initialSourcePolicy
    sourcePolicyStore = environment.sourcePolicyStore
    sourcePolicyPersistence = environment.sourcePolicyPersistence
  }

  func toggleDailyCapture() async {
    guard sourcePolicy.isEnabled(.audio) else { return }
    if capture.dailyState == .stopped, liveCapture.state == .running {
      await stopLiveMeeting()
    }
    await capture.toggle()
  }

  func toggleLiveMeeting() async {
    guard sourcePolicy.isEnabled(.audio) else { return }
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

  func setSource(_ source: DaylineContextSource, enabled: Bool) async {
    if source == .audio, !enabled {
      if capture.dailyState != .stopped {
        await capture.stop()
      }
      if liveCapture.state != .stopped {
        await stopLiveMeeting()
      }
    }
    let updated = sourcePolicy.setting(source, enabled: enabled)
    sourcePolicy = updated
    await sourcePolicyStore.replace(with: updated)
    sourcePolicyPersistence.save(updated)
  }

  private func stopLiveMeeting() async {
    await liveCapture.stop()
    await liveMeeting.end()
  }
}
