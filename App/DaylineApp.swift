import SwiftUI

@main
struct DaylineApp: App {
  @State private var model: DaylineAppModel

  init() {
    model = DaylineAppModel(environment: AppEnvironment.make())
  }

  var body: some Scene {
    WindowGroup {
      RootView(model: model)
    }
  }
}
