import XCTest

final class FramebaseUITests: XCTestCase {
    @MainActor
    func testLibrarySearchAndHistoryNavigation() {
        let app = XCUIApplication()
        app.launch()
        let addExists = app.buttons["library.add"].waitForExistence(timeout: 5)
        let neighborhoodExists = app.buttons["library.clip.neighborhood_crossing"].exists
        let downtownExists = app.buttons["library.clip.downtown_traffic"].exists
        let eveningExists = app.buttons["library.clip.evening_junction"].exists
        XCTAssertTrue(addExists)
        XCTAssertTrue(neighborhoodExists)
        XCTAssertTrue(downtownExists)
        XCTAssertTrue(eveningExists)
        app.buttons["library.search"].tap()
        let searchExists = app.textFields["search.query"].waitForExistence(timeout: 3)
        XCTAssertTrue(searchExists)
        app.buttons["search.back"].tap()
        app.buttons["library.menu"].tap()
        app.buttons["Sync history"].tap()
        let historyExists = app.navigationBars["Sync history"].waitForExistence(timeout: 3)
        XCTAssertTrue(historyExists)
    }
}
