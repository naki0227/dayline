import XCTest

final class DaylineCaptureUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testStartsAndStopsCaptureWithoutSystemPermissions() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

    let status = app.staticTexts["dayline.capture.status"]
    let toggle = app.buttons["dayline.capture.toggle"]
    XCTAssertTrue(status.waitForExistence(timeout: 5))
    XCTAssertEqual(status.label, "Dailyを開始")

    toggle.tap()
    XCTAssertTrue(waitForLabel("録音中", element: status))

    toggle.tap()
    XCTAssertTrue(waitForLabel("Dailyを開始", element: status))
  }

  func testDailyRemainsRunningWhileWaitingForCallAudio() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--ui-testing-audio-waiting"]
    app.launch()

    let status = app.staticTexts["dayline.capture.status"]
    let toggle = app.buttons["dayline.capture.toggle"]
    XCTAssertTrue(status.waitForExistence(timeout: 5))

    toggle.tap()

    XCTAssertTrue(waitForLabel("音声を待機中", element: status))
    XCTAssertEqual(toggle.label, "録音を停止")
  }

  func testDailySummaryShowsAnEmptyDayWithoutInvokingSystemIntelligence() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

    let generate = app.buttons["dayline.daily.generate"]
    let status = app.staticTexts["dayline.daily.status"]
    XCTAssertTrue(scrollToElement(generate, in: app))

    generate.tap()

    XCTAssertTrue(waitForLabel("今日のContextはまだありません。", element: status))
  }

  func testLiveMeetingShowsPersistentStateAndStopsCleanly() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.tabBars.buttons["Meetings"].tap()

    let toggle = app.buttons["dayline.live.toggle"]
    let status = app.staticTexts["dayline.live.status"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 5))

    toggle.tap()
    XCTAssertTrue(status.waitForExistence(timeout: 5))
    XCTAssertEqual(toggle.label, "会議を終了")

    toggle.tap()
    XCTAssertTrue(waitForLabel("会議を開始", element: toggle))
    XCTAssertFalse(status.exists)
  }

  func testPrivacyControlsDisableAudioCaptureAndRemainLocalOnly() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

    app.tabBars.buttons["Settings"].tap()
    app.buttons["dayline.settings.sources"].tap()

    let processing = app.staticTexts["dayline.privacy.processing"]
    let audio = app.switches["dayline.source.audio"]
    XCTAssertTrue(processing.waitForExistence(timeout: 5))
    XCTAssertEqual(processing.label, "詳細Contextは、明示した出力操作を除き端末外へ送りません。")
    XCTAssertTrue(audio.waitForExistence(timeout: 5))
    XCTAssertEqual(audio.value as? String, "1")

    audio.tap()

    XCTAssertEqual(audio.value as? String, "0")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.tabBars.buttons["Today"].tap()
    XCTAssertFalse(app.buttons["dayline.capture.toggle"].isEnabled)
  }

  func testNotionExportRequiresExplicitConfirmation() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--ui-testing-notion"]
    app.launch()

    let generate = app.buttons["dayline.daily.generate"]
    XCTAssertTrue(scrollToElement(generate, in: app))
    generate.tap()
    let open = app.buttons["dayline.notion.open"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    open.tap()

    let connect = app.buttons["dayline.notion.connect"]
    XCTAssertTrue(connect.waitForExistence(timeout: 5))
    connect.tap()
    XCTAssertTrue(app.staticTexts["dayline.notion.connected"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["dayline.notion.destination"].waitForExistence(timeout: 5))
    app.buttons["dayline.notion.prepare"].tap()

    let alert = app.alerts["Notionへ送信しますか？"]
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    alert.buttons["送信"].tap()
    XCTAssertTrue(app.staticTexts["dayline.notion.success"].waitForExistence(timeout: 5))
  }

  func testNotionConnectionShowsWorkspaceAndDisconnects() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--ui-testing-notion"]
    app.launch()

    let generate = app.buttons["dayline.daily.generate"]
    XCTAssertTrue(scrollToElement(generate, in: app))
    generate.tap()
    let open = app.buttons["dayline.notion.open"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    open.tap()

    let connect = app.buttons["dayline.notion.connect"]
    XCTAssertTrue(connect.waitForExistence(timeout: 5))
    connect.tap()
    let connected = app.staticTexts["dayline.notion.connected"]
    XCTAssertTrue(connected.waitForExistence(timeout: 5))
    XCTAssertEqual(connected.label, "UI Test Workspace")

    app.buttons["dayline.notion.disconnect"].tap()
    XCTAssertTrue(app.buttons["dayline.notion.connect"].waitForExistence(timeout: 5))
  }

  private func waitForLabel(_ label: String, element: XCUIElement) -> Bool {
    let predicate = NSPredicate(format: "label == %@", label)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
  }

  private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    if element.waitForExistence(timeout: 1) { return true }
    for _ in 0..<4 {
      app.swipeUp()
      if element.waitForExistence(timeout: 1) { return true }
    }
    return false
  }
}
