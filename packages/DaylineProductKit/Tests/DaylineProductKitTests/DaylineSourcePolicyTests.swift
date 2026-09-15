import Testing

@testable import DaylineProductKit

@Test
func sourcePolicyDefaultsToLocalAudioAndUpdatesImmutably() {
  let initial = DaylineSourcePolicy.localDefault
  let updated = initial.setting(.shell, enabled: true).setting(.audio, enabled: false)

  #expect(initial.enabledSources == [.audio])
  #expect(updated.enabledSources == [.shell])
  #expect(updated.contextSources.map(\.type) == ["shell"])
}

@Test
func sourcePolicyStorePublishesOneConsistentSnapshot() async {
  let store = DaylineSourcePolicyStore(policy: .localDefault)
  let updated = DaylineSourcePolicy(enabledSources: [.browser, .calendar])

  await store.replace(with: updated)

  #expect(await store.currentPolicy() == updated)
}
