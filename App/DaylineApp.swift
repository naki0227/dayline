import ContextCaptureKit
import DaylineProductKit
import SwiftUI

@main
struct DaylineApp: App {
  @State private var capture: CaptureCoordinator
  @State private var dailySummary: DailySummaryModel

  init() {
    let environment = AppEnvironment.make()
    capture = environment.capture
    dailySummary = environment.dailySummary
  }

  var body: some Scene {
    WindowGroup {
      RootView(capture: capture, dailySummary: dailySummary)
    }
  }
}
