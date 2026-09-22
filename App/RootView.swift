import SwiftUI

struct RootView: View {
  @Bindable var model: DaylineAppModel
  @State private var showsNotionExport = false

  var body: some View {
    TabView {
      TodayView(model: model) { showsNotionExport = true }
        .tabItem { Label("Today", systemImage: "house.fill") }

      TimelineView(model: model)
        .tabItem { Label("Timeline", systemImage: "list.bullet.rectangle") }

      LiveMeetingView(model: model)
        .tabItem { Label("Meetings", systemImage: "mic.fill") }

      SettingsView(model: model)
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
    }
    .tint(DaylineTheme.sky)
    .sheet(isPresented: $showsNotionExport) {
      if let artifact = model.dailySummary.summary {
        NotionExportView(
          artifact: artifact,
          model: model.notionExport,
          connection: model.notionConnection,
          configuration: model.notionConfiguration
        )
      }
    }
  }
}
