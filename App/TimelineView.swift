import SwiftUI

struct TimelineView: View {
  @Bindable var model: DaylineAppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if let presentation = model.dailySummary.presentation {
            VStack(alignment: .leading, spacing: 12) {
              Label("今日のまとめ", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(DaylineTheme.sky)
              ArtifactSectionsView(
                presentation: presentation,
                accessibilityPrefix: "dayline.timeline.daily"
              )
            }
            .daylineCard()
          } else {
            ContentUnavailableView {
              Label("まだTimelineはありません", systemImage: "clock.arrow.circlepath")
            } description: {
              Text("Daily録音やLive Meetingから確定したContextがここに並びます。")
            } actions: {
              Button("今日を要約") {
                Task { await model.dailySummary.generate() }
              }
              .buttonStyle(.borderedProminent)
              .tint(DaylineTheme.sky)
              .accessibilityIdentifier("dayline.daily.generate")
            }
          }
        }
        .padding(20)
      }
      .background(DaylineTheme.canvas.opacity(0.55).ignoresSafeArea())
      .navigationTitle("Timeline")
    }
  }
}
