import ContextCaptureKit
import SwiftUI

@main
struct DaylineApp: App {
  @State private var capture: CaptureCoordinator

  init() {
    capture = AppCaptureEnvironment.makeCoordinator()
  }

  var body: some Scene {
    WindowGroup {
      RootView(capture: capture)
    }
  }
}
