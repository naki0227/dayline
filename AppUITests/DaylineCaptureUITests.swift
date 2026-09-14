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

  private func waitForLabel(_ label: String, element: XCUIElement) -> Bool {
    let predicate = NSPredicate(format: "label == %@", label)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
  }
}
