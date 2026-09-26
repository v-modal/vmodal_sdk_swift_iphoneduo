import XCTest
@testable import StarterIOS

final class StarterIOSTests: XCTestCase {
    @MainActor
    func testSessionStartsWithoutNetworkWork() {
        let session = AppSession()
        XCTAssertEqual(session.collections, [])
        XCTAssertEqual(session.uploadPercent, 0)
        XCTAssertEqual(session.message, "Enter a token to connect.")
    }
}
