import Testing

@testable import DaylineProductKit

@Test
func loadsTheVersionedDailyAndLiveProfiles() throws {
  let catalog = DaylineProfileCatalog()
  let daily = try catalog.load(.dailySummary)
  let live = try catalog.load(.liveMeeting)

  #expect(daily.version == 1)
  #expect(daily.update.mode == .batch)
  #expect(daily.output.contains("decisions"))
  #expect(live.update.mode == .incremental)
  #expect(live.update.minimumIntervalSeconds == 30)
  #expect(live.output.contains("response-suggestions"))
}

@Test
func rejectsInvalidProfileInvariants() {
  let profile = DaylineAIProfile(
    id: .liveMeeting,
    version: 1,
    sources: ["audio", "audio"],
    output: ["summary"],
    displayLanguage: "ja",
    tools: ProfileToolPolicy(read: [], write: []),
    update: ProfileUpdatePolicy(mode: .incremental, minimumIntervalSeconds: 0)
  )

  #expect(throws: DaylineProfileError.duplicateEntry) {
    try profile.validate()
  }
}
