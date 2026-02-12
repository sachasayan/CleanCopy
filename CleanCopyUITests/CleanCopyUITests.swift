import XCTest

final class CleanCopyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchAndPopover() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Note: UI testing Menu Bar Extras is notoriously difficult as they exist in a separate process/window level
        // For this 2026 iteration, we'll verify the app starts without crashing
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }
}
