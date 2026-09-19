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
    XCTAssertEqual(status.label, "停止中")

    toggle.tap()
    XCTAssertTrue(waitForLabel("録音中", element: status))

    toggle.tap()
    XCTAssertTrue(waitForLabel("停止中", element: status))
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
    XCTAssertTrue(generate.waitForExistence(timeout: 5))

    generate.tap()

    XCTAssertTrue(waitForLabel("今日のContextはまだありません。", element: status))
  }

  func testLiveMeetingShowsPersistentStateAndStopsCleanly() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

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

    let processing = app.staticTexts["dayline.privacy.processing"]
    let audio = app.switches["dayline.source.audio"]
    let capture = app.buttons["dayline.capture.toggle"]
    XCTAssertTrue(processing.waitForExistence(timeout: 5))
    XCTAssertEqual(processing.label, "端末内のみ")
    XCTAssertTrue(audio.waitForExistence(timeout: 5))
    XCTAssertEqual(audio.value as? String, "1")

    audio.tap()

    XCTAssertEqual(audio.value as? String, "0")
    XCTAssertFalse(capture.isEnabled)
  }

  func testNotionExportRequiresExplicitConfirmation() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--ui-testing-notion"]
    app.launch()

    app.buttons["dayline.daily.generate"].tap()
    let open = app.buttons["dayline.notion.open"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    open.tap()

    let connect = app.buttons["dayline.notion.connect"]
    let parent = app.textFields["dayline.notion.parent"]
    XCTAssertTrue(connect.waitForExistence(timeout: 5))
    connect.tap()
    XCTAssertTrue(app.staticTexts["dayline.notion.connected"].waitForExistence(timeout: 5))
    parent.tap()
    parent.typeText("parent-page")
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

    app.buttons["dayline.daily.generate"].tap()
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
}
